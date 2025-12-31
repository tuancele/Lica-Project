#!/bin/bash

echo "🚀 Đang nâng cấp Logic Voucher V2 (Product Specific & Private Mode)..."

cd /var/www/lica-project/backend

# ==============================================================================
# 1. DATABASE: Thêm cột is_public và max_discount_amount
# ==============================================================================
echo "📦 Cập nhật Migration Coupons..."
TIMESTAMP=$(date +"%Y_%m_%d_%H%M%S")

cat << EOF > Modules/Order/database/migrations/${TIMESTAMP}_add_advanced_fields_to_coupons.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('coupons', function (Blueprint \$table) {
            if (!Schema::hasColumn('coupons', 'is_public')) {
                \$table->boolean('is_public')->default(true)->after('is_active'); // True: Hiện list, False: Chỉ nhập tay
            }
            if (!Schema::hasColumn('coupons', 'max_discount_amount')) {
                \$table->decimal('max_discount_amount', 15, 2)->nullable()->after('value'); // Giảm tối đa (cho %)
            }
        });
    }

    public function down(): void
    {
        Schema::table('coupons', function (Blueprint \$table) {
            \$table->dropColumn(['is_public', 'max_discount_amount']);
        });
    }
};
EOF

php artisan migrate --force

# ==============================================================================
# 2. BACKEND: Cập nhật CouponController & OrderController
# ==============================================================================
echo "⚙️ Cập nhật Logic Tính toán Voucher..."

# 2.1 Cập nhật OrderController (Logic tính toán cốt lõi)
cat << 'EOF' > Modules/Order/app/Http/Controllers/OrderController.php
<?php

namespace Modules\Order\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Order\Models\Order;
use Modules\Order\Models\Coupon;
use Modules\Product\Models\Product;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;

class OrderController extends Controller
{
    /**
     * LOGIC TÍNH TOÁN GIẢM GIÁ NÂNG CAO
     */
    private function calculateDiscount($couponCode, $cartItems)
    {
        $coupon = Coupon::where('code', $couponCode)->where('is_active', true)->first();
        
        if (!$coupon) return ['error' => 'Mã giảm giá không tồn tại.'];

        // 1. Check thời gian
        $now = now();
        if ($coupon->start_date && $now < $coupon->start_date) return ['error' => 'Mã chưa đến thời gian sử dụng.'];
        if ($coupon->end_date && $now > $coupon->end_date) return ['error' => 'Mã đã hết hạn sử dụng.'];

        // 2. Check lượt dùng
        if ($coupon->usage_limit > 0 && $coupon->used_count >= $coupon->usage_limit) return ['error' => 'Mã đã hết lượt sử dụng.'];

        // 3. Phân tích giỏ hàng
        $cartTotal = 0;        // Tổng tiền cả đơn
        $eligibleTotal = 0;    // Tổng tiền của các sản phẩm ĐƯỢC PHÉP áp dụng
        
        $allowedProductIds = $coupon->apply_type === 'specific' ? $coupon->products->pluck('id')->toArray() : [];

        foreach ($cartItems as $item) {
            $p = Product::find($item['product_id']);
            if($p) {
                $price = $p->sale_price > 0 ? $p->sale_price : $p->price;
                $rowTotal = $price * $item['quantity'];
                
                $cartTotal += $rowTotal;

                // Nếu là voucher toàn shop HOẶC sản phẩm này nằm trong danh sách cho phép
                if ($coupon->apply_type === 'all' || in_array($p->id, $allowedProductIds)) {
                    $eligibleTotal += $rowTotal;
                }
            }
        }

        // 4. Check Đơn tối thiểu (Thường so sánh với Tổng đơn hàng)
        if ($cartTotal < $coupon->min_order_value) {
            return ['error' => 'Đơn hàng chưa đạt tối thiểu ' . number_format($coupon->min_order_value) . 'đ để dùng mã này.'];
        }

        // 5. Nếu Voucher sản phẩm mà không có sản phẩm nào hợp lệ
        if ($eligibleTotal == 0) {
            return ['error' => 'Mã này không áp dụng cho các sản phẩm trong giỏ hàng của bạn.'];
        }

        // 6. Tính toán số tiền giảm
        $discount = 0;
        if ($coupon->type === 'percent') {
            // Giảm theo % của TỔNG TIỀN HỢP LỆ (Eligible Total)
            $discount = $eligibleTotal * ($coupon->value / 100);
            
            // Check giảm tối đa (Cap)
            if ($coupon->max_discount_amount > 0 && $discount > $coupon->max_discount_amount) {
                $discount = $coupon->max_discount_amount;
            }
        } else {
            // Giảm tiền mặt cố định
            $discount = $coupon->value;
        }

        // 7. Final Check: Không giảm quá số tiền của các sản phẩm hợp lệ
        if ($discount > $eligibleTotal) {
            $discount = $eligibleTotal;
        }

        return ['discount' => $discount, 'coupon' => $coupon];
    }

    public function checkCoupon(Request $request)
    {
        $res = $this->calculateDiscount($request->code, $request->items);
        if (isset($res['error'])) return response()->json(['status' => 400, 'message' => $res['error']], 400);
        return response()->json(['status' => 200, 'data' => ['discount' => $res['discount']]]);
    }

    public function checkout(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'customer_name' => 'required', 'customer_phone' => 'required', 'shipping_address' => 'required', 'items' => 'required|array|min:1',
        ]);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        DB::beginTransaction();
        try {
            $input = $request->all();
            $userId = auth('sanctum')->id();
            $totalAmount = 0;
            $orderItemsData = [];

            foreach ($input['items'] as $item) {
                $product = Product::lockForUpdate()->find($item['product_id']);
                if (!$product || $product->stock_quantity < $item['quantity']) { DB::rollBack(); return response()->json(['status' => 400, 'message' => "Sản phẩm lỗi hoặc hết hàng."], 400); }
                
                $price = $product->sale_price > 0 ? $product->sale_price : $product->price;
                $lineTotal = $price * $item['quantity'];
                $totalAmount += $lineTotal;
                
                $orderItemsData[] = [
                    'product_id' => $product->id, 'product_name' => $product->name, 'sku' => $product->sku,
                    'quantity' => $item['quantity'], 'price' => $price, 'total' => $lineTotal,
                    'options' => json_encode($item['options'] ?? [])
                ];
                $product->decrement('stock_quantity', $item['quantity']);
            }

            $discountAmount = 0;
            $couponCode = null;

            if (!empty($input['coupon_code'])) {
                $couponRes = $this->calculateDiscount($input['coupon_code'], $input['items']);
                if (!isset($couponRes['error'])) {
                    $discountAmount = $couponRes['discount'];
                    $couponCode = $input['coupon_code'];
                    $couponRes['coupon']->increment('used_count');
                }
            }

            $finalTotal = max(0, $totalAmount - $discountAmount);
            
            $order = Order::create([
                'user_id' => $userId,
                'customer_name' => $input['customer_name'],
                'customer_phone' => $input['customer_phone'],
                'customer_email' => $input['customer_email'] ?? null,
                'shipping_address' => $input['shipping_address'],
                'note' => $input['note'] ?? null,
                'total_amount' => $finalTotal,
                'discount_amount' => $discountAmount,
                'coupon_code' => $couponCode,
                'payment_method' => $input['payment_method'] ?? 'cod',
                'status' => 'pending'
            ]);

            foreach ($orderItemsData as $data) { $order->items()->create($data); }
            DB::commit();

            return response()->json(['status' => 200, 'message' => 'Thành công', 'data' => ['redirect_url' => "/order/success/{$order->hash_id}"]]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }

    public function getOrderByHash($hash) { return response()->json(['status' => 200, 'data' => Order::with('items')->where('hash_id', $hash)->first()]); }
    public function index(Request $request) { return response()->json(['status' => 200, 'data' => Order::orderBy('created_at','desc')->paginate(10)]); }
    public function show($id) { return response()->json(['status' => 200, 'data' => Order::with('items.product')->find($id)]); }
}
EOF

# 2.2 Cập nhật CouponController (Thêm trường mới vào Store/Update)
cat << 'EOF' > Modules/Order/app/Http/Controllers/CouponController.php
<?php

namespace Modules\Order\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Order\Models\Coupon;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class CouponController extends Controller
{
    public function index(Request $request)
    {
        $query = Coupon::withCount('products')->orderBy('created_at', 'desc');
        if ($request->q) {
            $query->where('code', 'like', "%{$request->q}%")->orWhere('name', 'like', "%{$request->q}%");
        }
        return response()->json(['status' => 200, 'data' => $query->paginate(20)]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'code' => 'required|unique:coupons,code|uppercase',
            'name' => 'required',
            'value' => 'required|numeric|min:0',
            'start_date' => 'required|date',
            'end_date' => 'required|date|after:start_date',
        ]);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        DB::beginTransaction();
        try {
            $data = $request->except('product_ids');
            $data['apply_type'] = count($request->product_ids ?? []) > 0 ? 'specific' : 'all';
            $coupon = Coupon::create($data);
            if ($request->has('product_ids')) $coupon->products()->sync($request->product_ids);
            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Tạo thành công']);
        } catch (\Exception $e) { DB::rollBack(); return response()->json(['status' => 500, 'message' => $e->getMessage()], 500); }
    }

    public function update(Request $request, $id)
    {
        $coupon = Coupon::find($id);
        if (!$coupon) return response()->json(['message' => 'Not found'], 404);
        
        $validator = Validator::make($request->all(), [
            'code' => ['required', 'uppercase', Rule::unique('coupons')->ignore($coupon->id)],
            'name' => 'required',
            'value' => 'required|numeric|min:0',
        ]);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        DB::beginTransaction();
        try {
            $data = $request->except('product_ids');
            $data['apply_type'] = count($request->product_ids ?? []) > 0 ? 'specific' : 'all';
            $coupon->update($data);
            if ($request->has('product_ids')) $coupon->products()->sync($request->product_ids);
            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Cập nhật thành công']);
        } catch (\Exception $e) { DB::rollBack(); return response()->json(['status' => 500, 'message' => $e->getMessage()], 500); }
    }

    public function show($id) {
        $coupon = Coupon::with('products:id,name,thumbnail,sku')->find($id);
        if (!$coupon) return response()->json(['message' => 'Not found'], 404);
        $coupon->product_ids = $coupon->products->pluck('id');
        return response()->json(['status' => 200, 'data' => $coupon]);
    }
    public function destroy($id) { Coupon::destroy($id); return response()->json(['status' => 200, 'message' => 'Deleted']); }
}
EOF

# ==============================================================================
# 3. FRONTEND ADMIN: Cập nhật Form Create/Edit Coupon
# ==============================================================================
echo "💻 Cập nhật Admin UI (Thêm trường Public/Private & Max Discount)..."

# Sửa trang CREATE
cat << 'EOF' > /var/www/lica-project/apps/admin/app/marketing/coupons/create/page.tsx
"use client";
import { useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, Save, Plus, HelpCircle } from "lucide-react";
import ProductSelector from "@/components/marketing/ProductSelector";

export default function CreateCouponPage() {
  const router = useRouter();
  const [form, setForm] = useState({
    name: "", code: "", type: "fixed", value: 0, min_order_value: 0, usage_limit: 100,
    start_date: "", end_date: "", product_ids: [] as number[],
    is_public: true, max_discount_amount: 0
  });
  const [showProductModal, setShowProductModal] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
        await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/marketing/coupons`, form);
        alert("Tạo mã thành công!");
        router.push("/marketing/coupons");
    } catch (err: any) { alert(err.response?.data?.message || "Lỗi tạo mã"); } finally { setLoading(false); }
  };

  return (
    <div className="p-6 bg-gray-50 min-h-screen pb-20">
      <form onSubmit={handleSubmit} className="max-w-4xl mx-auto">
        <div className="flex items-center gap-4 mb-6">
            <Link href="/marketing/coupons" className="p-2 border rounded hover:bg-white"><ArrowLeft size={20}/></Link>
            <h1 className="text-2xl font-bold">Tạo Mã Giảm Giá Mới</h1>
        </div>

        <div className="space-y-6">
            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <h3 className="font-bold border-b pb-3 mb-4">Cấu hình hiển thị</h3>
                <div className="flex gap-6">
                    <label className="flex items-center gap-2 cursor-pointer">
                        <input type="radio" name="is_public" checked={form.is_public === true} onChange={() => setForm({...form, is_public: true})} className="w-5 h-5 accent-blue-600"/>
                        <div>
                            <div className="font-medium">Công khai</div>
                            <div className="text-xs text-gray-500">Mã sẽ hiện trong trang danh sách mã giảm giá của Shop.</div>
                        </div>
                    </label>
                    <label className="flex items-center gap-2 cursor-pointer">
                        <input type="radio" name="is_public" checked={form.is_public === false} onChange={() => setForm({...form, is_public: false})} className="w-5 h-5 accent-blue-600"/>
                        <div>
                            <div className="font-medium">Ẩn (Không công khai)</div>
                            <div className="text-xs text-gray-500">Mã không hiển thị, Khách hàng phải nhập mã để áp dụng (Dùng cho Ads, KOL).</div>
                        </div>
                    </label>
                </div>
            </div>

            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <h3 className="font-bold border-b pb-3 mb-4">Thông tin cơ bản</h3>
                <div className="grid grid-cols-2 gap-4 mb-4">
                    <div><label className="block text-sm font-medium mb-1">Tên chương trình</label><input className="w-full border rounded p-2" required value={form.name} onChange={e => setForm({...form, name: e.target.value})} placeholder="VD: Sale Tết 2026"/></div>
                    <div><label className="block text-sm font-medium mb-1">Mã Voucher (Tối đa 20 ký tự)</label><input className="w-full border rounded p-2 uppercase" required value={form.code} onChange={e => setForm({...form, code: e.target.value.toUpperCase()})} placeholder="VD: TET2026"/></div>
                </div>
                <div className="grid grid-cols-2 gap-4">
                    <div><label className="block text-sm font-medium mb-1">Thời gian bắt đầu</label><input type="datetime-local" className="w-full border rounded p-2" required onChange={e => setForm({...form, start_date: e.target.value})}/></div>
                    <div><label className="block text-sm font-medium mb-1">Thời gian kết thúc</label><input type="datetime-local" className="w-full border rounded p-2" required onChange={e => setForm({...form, end_date: e.target.value})}/></div>
                </div>
            </div>

            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <h3 className="font-bold border-b pb-3 mb-4">Thiết lập giảm giá</h3>
                <div className="grid grid-cols-2 gap-4 mb-4">
                    <div>
                        <label className="block text-sm font-medium mb-1">Loại giảm giá</label>
                        <select className="w-full border rounded p-2" value={form.type} onChange={e => setForm({...form, type: e.target.value})}>
                            <option value="fixed">Theo số tiền (VNĐ)</option>
                            <option value="percent">Theo phần trăm (%)</option>
                        </select>
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-1">Mức giảm</label>
                        <input type="number" className="w-full border rounded p-2" required value={form.value} onChange={e => setForm({...form, value: Number(e.target.value)})}/>
                    </div>
                </div>
                
                {form.type === 'percent' && (
                    <div className="mb-4">
                        <label className="block text-sm font-medium mb-1 text-blue-800">Mức giảm tối đa (VNĐ)</label>
                        <input type="number" className="w-full border border-blue-200 bg-blue-50 rounded p-2" placeholder="Nhập 0 nếu không giới hạn" value={form.max_discount_amount} onChange={e => setForm({...form, max_discount_amount: Number(e.target.value)})}/>
                        <p className="text-xs text-gray-500 mt-1">Ví dụ: Giảm 50% nhưng tối đa 50.000đ. Nhập 0 để không giới hạn.</p>
                    </div>
                )}

                <div className="grid grid-cols-2 gap-4">
                    <div><label className="block text-sm font-medium mb-1">Đơn tối thiểu</label><input type="number" className="w-full border rounded p-2" required value={form.min_order_value} onChange={e => setForm({...form, min_order_value: Number(e.target.value)})}/></div>
                    <div><label className="block text-sm font-medium mb-1">Tổng lượt sử dụng tối đa</label><input type="number" className="w-full border rounded p-2" required value={form.usage_limit} onChange={e => setForm({...form, usage_limit: Number(e.target.value)})}/></div>
                </div>
            </div>

            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <h3 className="font-bold border-b pb-3 mb-4">Sản phẩm áp dụng</h3>
                <div className="mb-4">
                    <label className="flex items-center gap-2 mb-2"><input type="radio" name="apply" checked={form.product_ids.length === 0} onChange={() => setForm({...form, product_ids: []})} /><span>Toàn bộ sản phẩm</span></label>
                    <label className="flex items-center gap-2"><input type="radio" name="apply" checked={form.product_ids.length > 0} onChange={() => setShowProductModal(true)} /><span>Sản phẩm nhất định</span></label>
                </div>
                {form.product_ids.length > 0 && (
                    <div className="p-4 bg-blue-50 border border-blue-100 rounded-lg flex justify-between items-center">
                        <span className="font-bold text-blue-800">Đã chọn {form.product_ids.length} sản phẩm</span>
                        <button type="button" onClick={() => setShowProductModal(true)} className="text-sm text-blue-600 underline">Chỉnh sửa</button>
                    </div>
                )}
            </div>
        </div>

        <div className="fixed bottom-0 left-0 right-0 bg-white border-t p-4 flex justify-end gap-4 shadow-lg z-40">
            <Link href="/marketing/coupons" className="px-6 py-2 border rounded hover:bg-gray-100">Hủy</Link>
            <button type="submit" disabled={loading} className="px-8 py-2 bg-red-600 text-white font-bold rounded hover:bg-red-700 flex items-center gap-2">
                <Save size={18}/> {loading ? "Đang lưu..." : "Lưu & Kích hoạt"}
            </button>
        </div>
      </form>

      {showProductModal && <ProductSelector selectedIds={form.product_ids} onChange={(ids) => setForm({...form, product_ids: ids})} onClose={() => setShowProductModal(false)} />}
    </div>
  );
}
EOF

# Sửa trang EDIT (Tương tự Create nhưng có fill data)
cat << 'EOF' > /var/www/lica-project/apps/admin/app/marketing/coupons/[id]/page.tsx
"use client";
import { useState, useEffect, use } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, Save, Loader2 } from "lucide-react";
import ProductSelector from "@/components/marketing/ProductSelector";

export default function EditCouponPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [showProductModal, setShowProductModal] = useState(false);

  const [form, setForm] = useState({
    name: "", code: "", type: "fixed", value: 0, min_order_value: 0, usage_limit: 100,
    start_date: "", end_date: "", product_ids: [] as number[],
    is_active: true, is_public: true, max_discount_amount: 0
  });

  useEffect(() => {
    const fetchData = async () => {
      try {
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/marketing/coupons/${id}`);
        const data = res.data.data;
        const formatTime = (isoString: string) => isoString ? new Date(isoString).toISOString().slice(0, 16) : "";
        setForm({
            name: data.name, code: data.code, type: data.type, value: Number(data.value),
            min_order_value: Number(data.min_order_value), usage_limit: Number(data.usage_limit),
            start_date: formatTime(data.start_date), end_date: formatTime(data.end_date),
            product_ids: data.product_ids || [], is_active: Boolean(data.is_active),
            is_public: data.is_public !== undefined ? Boolean(data.is_public) : true,
            max_discount_amount: Number(data.max_discount_amount || 0)
        });
      } catch (err) { alert("Lỗi tải dữ liệu"); router.push("/marketing/coupons"); } finally { setLoading(false); }
    };
    fetchData();
  }, [id, router]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
        await axios.put(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/marketing/coupons/${id}`, form);
        alert("Cập nhật thành công!");
        router.push("/marketing/coupons");
    } catch (err: any) { alert(err.response?.data?.message || "Lỗi cập nhật"); } finally { setSaving(false); }
  };

  if (loading) return <div className="h-screen flex items-center justify-center"><Loader2 className="animate-spin text-blue-600"/></div>;

  return (
    <div className="p-6 bg-gray-50 min-h-screen pb-20">
      <form onSubmit={handleSubmit} className="max-w-4xl mx-auto">
        <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-4">
                <Link href="/marketing/coupons" className="p-2 border rounded hover:bg-white"><ArrowLeft size={20}/></Link>
                <h1 className="text-2xl font-bold">Chỉnh sửa Voucher</h1>
            </div>
            <div className="flex items-center gap-2">
                <button type="button" onClick={() => setForm({...form, is_active: !form.is_active})} className={`px-3 py-1 rounded-full text-xs font-bold ${form.is_active?'bg-green-100 text-green-700':'bg-gray-200 text-gray-600'}`}>{form.is_active?'Đang hoạt động':'Tạm dừng'}</button>
            </div>
        </div>

        <div className="space-y-6">
            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <h3 className="font-bold border-b pb-3 mb-4">Cấu hình hiển thị</h3>
                <div className="flex gap-6">
                    <label className="flex items-center gap-2 cursor-pointer"><input type="radio" name="is_public" checked={form.is_public===true} onChange={()=>setForm({...form, is_public:true})} className="w-5 h-5 accent-blue-600"/><div className="font-medium">Công khai</div></label>
                    <label className="flex items-center gap-2 cursor-pointer"><input type="radio" name="is_public" checked={form.is_public===false} onChange={()=>setForm({...form, is_public:false})} className="w-5 h-5 accent-blue-600"/><div className="font-medium">Ẩn (Private)</div></label>
                </div>
            </div>

            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <div className="grid grid-cols-2 gap-4 mb-4">
                    <div><label className="block text-sm font-medium mb-1">Tên chương trình</label><input className="w-full border rounded p-2" required value={form.name} onChange={e=>setForm({...form, name: e.target.value})}/></div>
                    <div><label className="block text-sm font-medium mb-1">Mã Voucher</label><input className="w-full border rounded p-2 uppercase" required value={form.code} onChange={e=>setForm({...form, code: e.target.value.toUpperCase()})}/></div>
                </div>
                <div className="grid grid-cols-2 gap-4">
                    <div><label className="block text-sm font-medium mb-1">Bắt đầu</label><input type="datetime-local" className="w-full border rounded p-2" required value={form.start_date} onChange={e=>setForm({...form, start_date: e.target.value})}/></div>
                    <div><label className="block text-sm font-medium mb-1">Kết thúc</label><input type="datetime-local" className="w-full border rounded p-2" required value={form.end_date} onChange={e=>setForm({...form, end_date: e.target.value})}/></div>
                </div>
            </div>

            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <div className="grid grid-cols-2 gap-4 mb-4">
                    <div><label className="block text-sm font-medium mb-1">Loại</label><select className="w-full border rounded p-2" value={form.type} onChange={e=>setForm({...form, type: e.target.value})}><option value="fixed">Tiền (VNĐ)</option><option value="percent">%</option></select></div>
                    <div><label className="block text-sm font-medium mb-1">Mức giảm</label><input type="number" className="w-full border rounded p-2" required value={form.value} onChange={e=>setForm({...form, value: Number(e.target.value)})}/></div>
                </div>
                {form.type === 'percent' && (<div className="mb-4"><label className="block text-sm font-medium mb-1 text-blue-800">Tối đa (VNĐ)</label><input type="number" className="w-full border border-blue-200 bg-blue-50 rounded p-2" value={form.max_discount_amount} onChange={e=>setForm({...form, max_discount_amount: Number(e.target.value)})}/></div>)}
                <div className="grid grid-cols-2 gap-4">
                    <div><label className="block text-sm font-medium mb-1">Đơn tối thiểu</label><input type="number" className="w-full border rounded p-2" required value={form.min_order_value} onChange={e=>setForm({...form, min_order_value: Number(e.target.value)})}/></div>
                    <div><label className="block text-sm font-medium mb-1">Lượt dùng tối đa</label><input type="number" className="w-full border rounded p-2" required value={form.usage_limit} onChange={e=>setForm({...form, usage_limit: Number(e.target.value)})}/></div>
                </div>
            </div>

            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <div className="mb-4">
                    <label className="flex items-center gap-2 mb-2"><input type="radio" name="apply" checked={form.product_ids.length === 0} onChange={()=>setForm({...form, product_ids: []})} /><span>Toàn bộ sản phẩm</span></label>
                    <label className="flex items-center gap-2"><input type="radio" name="apply" checked={form.product_ids.length > 0} onChange={()=>setShowProductModal(true)} /><span>Sản phẩm nhất định</span></label>
                </div>
                {form.product_ids.length > 0 && <div className="p-4 bg-blue-50 border border-blue-100 rounded-lg flex justify-between items-center"><span className="font-bold text-blue-800">Đã chọn {form.product_ids.length} sản phẩm</span><button type="button" onClick={()=>setShowProductModal(true)} className="text-sm text-blue-600 underline">Chỉnh sửa</button></div>}
            </div>
        </div>

        <div className="fixed bottom-0 left-0 right-0 bg-white border-t p-4 flex justify-end gap-4 shadow-lg z-40">
            <Link href="/marketing/coupons" className="px-6 py-2 border rounded hover:bg-gray-100">Hủy</Link>
            <button type="submit" disabled={saving} className="px-8 py-2 bg-blue-600 text-white font-bold rounded hover:bg-blue-700 flex items-center gap-2"><Save size={18}/> {saving ? "Đang lưu..." : "Cập nhật"}</button>
        </div>
      </form>
      {showProductModal && <ProductSelector selectedIds={form.product_ids} onChange={(ids) => setForm({...form, product_ids: ids})} onClose={() => setShowProductModal(false)} />}
    </div>
  );
}
EOF

# ==============================================================================
# BUILD LẠI ADMIN
# ==============================================================================
echo "🔄 Build lại Admin..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Hoàn tất nâng cấp Logic Voucher V2!"
