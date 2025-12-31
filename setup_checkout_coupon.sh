#!/bin/bash

echo "🚀 Đang tích hợp Mã giảm giá vào quy trình Đặt hàng..."

cd /var/www/lica-project/backend

# ==============================================================================
# 1. DATABASE: Thêm cột coupon vào bảng Orders
# ==============================================================================
echo "📦 Cập nhật Migration Orders..."
TIMESTAMP=$(date +"%Y_%m_%d_%H%M%S")

cat << EOF > Modules/Order/database/migrations/${TIMESTAMP}_add_coupon_to_orders.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint \$table) {
            if (!Schema::hasColumn('orders', 'coupon_code')) {
                \$table->string('coupon_code')->nullable()->after('payment_method');
            }
            if (!Schema::hasColumn('orders', 'discount_amount')) {
                \$table->decimal('discount_amount', 15, 2)->default(0)->after('coupon_code');
            }
        });
    }

    public function down(): void
    {
        Schema::table('orders', function (Blueprint \$table) {
            \$table->dropColumn(['coupon_code', 'discount_amount']);
        });
    }
};
EOF

# Chạy migrate ngay
php artisan migrate --force

# ==============================================================================
# 2. BACKEND: Cập nhật OrderController (Logic tính toán Coupon)
# ==============================================================================
echo "⚙️ Cập nhật OrderController (Logic Coupon)..."

cat << 'EOF' > Modules/Order/app/Http/Controllers/OrderController.php
<?php

namespace Modules\Order\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Order\Models\Order;
use Modules\Order\Models\OrderItem;
use Modules\Order\Models\Coupon;
use Modules\Product\Models\Product;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;

class OrderController extends Controller
{
    // --- HELPER: Tính toán giảm giá ---
    private function calculateDiscount($couponCode, $cartItems)
    {
        $coupon = Coupon::where('code', $couponCode)->where('is_active', true)->first();
        
        if (!$coupon) return ['error' => 'Mã giảm giá không tồn tại hoặc đã hết hạn.'];

        // Check thời gian
        $now = now();
        if ($coupon->start_date && $now < $coupon->start_date) return ['error' => 'Mã chưa đến thời gian sử dụng.'];
        if ($coupon->end_date && $now > $coupon->end_date) return ['error' => 'Mã đã hết hạn sử dụng.'];

        // Check lượt dùng
        if ($coupon->usage_limit > 0 && $coupon->used_count >= $coupon->usage_limit) return ['error' => 'Mã đã hết lượt sử dụng.'];

        // Tính tổng tiền giỏ hàng (để check min order)
        $cartTotal = 0;
        $validItemsTotal = 0; // Tổng tiền các SP được phép áp dụng mã
        
        // Lấy danh sách Product ID được áp dụng (nếu có)
        $allowedProductIds = $coupon->apply_type === 'specific' ? $coupon->products->pluck('id')->toArray() : [];

        foreach ($cartItems as $item) {
            // Lưu ý: $item['price'] phải lấy từ DB để an toàn, nhưng ở đây ta giả định dữ liệu đã check
            // Tốt nhất là query lại DB. Ở đây làm nhanh trong hàm checkout.
            $p = Product::find($item['product_id']);
            if($p) {
                $price = $p->sale_price > 0 ? $p->sale_price : $p->price;
                $rowTotal = $price * $item['quantity'];
                $cartTotal += $rowTotal;

                if ($coupon->apply_type === 'all' || in_array($p->id, $allowedProductIds)) {
                    $validItemsTotal += $rowTotal;
                }
            }
        }

        if ($cartTotal < $coupon->min_order_value) {
            return ['error' => 'Đơn hàng chưa đạt giá trị tối thiểu: ' . number_format($coupon->min_order_value) . 'đ'];
        }

        if ($validItemsTotal == 0) {
            return ['error' => 'Mã này không áp dụng cho các sản phẩm trong giỏ hàng.'];
        }

        // Tính giảm giá
        $discount = 0;
        if ($coupon->type === 'percent') {
            $discount = $validItemsTotal * ($coupon->value / 100);
        } else {
            $discount = $coupon->value;
        }

        // Không giảm quá tổng tiền
        if ($discount > $cartTotal) $discount = $cartTotal;

        return ['discount' => $discount, 'coupon' => $coupon];
    }

    // --- API CHECK COUPON (Frontend gọi để hiển thị) ---
    public function checkCoupon(Request $request)
    {
        $res = $this->calculateDiscount($request->code, $request->items);
        if (isset($res['error'])) {
            return response()->json(['status' => 400, 'message' => $res['error']], 400);
        }
        return response()->json(['status' => 200, 'data' => ['discount' => $res['discount']]]);
    }

    // --- API CHECKOUT (Cập nhật) ---
    public function checkout(Request $request)
    {
        Log::info('Checkout Data:', $request->all());

        $validator = Validator::make($request->all(), [
            'customer_name' => 'required|string',
            'customer_phone' => 'required|string',
            'shipping_address' => 'required|string',
            'items' => 'required|array|min:1',
        ]);

        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        DB::beginTransaction();
        try {
            $input = $request->all();
            $userId = auth('sanctum')->id();
            $totalAmount = 0;
            $orderItemsData = [];

            // 1. Duyệt sản phẩm & Tính tổng tạm
            foreach ($input['items'] as $item) {
                $product = Product::lockForUpdate()->find($item['product_id']);
                if (!$product) { DB::rollBack(); return response()->json(['status' => 400, 'message' => "Sản phẩm ID {$item['product_id']} lỗi."], 400); }
                if ($product->stock_quantity < $item['quantity']) { DB::rollBack(); return response()->json(['status' => 400, 'message' => "{$product->name} hết hàng."], 400); }

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

            // 2. Xử lý Coupon (Nếu có)
            $discountAmount = 0;
            $couponCode = null;

            if (!empty($input['coupon_code'])) {
                // Tính toán lại chính xác trên server, không tin client
                $couponRes = $this->calculateDiscount($input['coupon_code'], $input['items']);
                
                if (!isset($couponRes['error'])) {
                    $discountAmount = $couponRes['discount'];
                    $couponCode = $input['coupon_code'];
                    
                    // Tăng lượt dùng coupon
                    $couponRes['coupon']->increment('used_count');
                }
            }

            // 3. Tạo Order
            $finalTotal = max(0, $totalAmount - $discountAmount);
            
            $order = Order::create([
                'user_id' => $userId,
                'customer_name' => $input['customer_name'],
                'customer_phone' => $input['customer_phone'],
                'customer_email' => $input['customer_email'] ?? null,
                'shipping_address' => $input['shipping_address'],
                'note' => $input['note'] ?? null,
                'total_amount' => $finalTotal, // Đã trừ giảm giá
                'discount_amount' => $discountAmount,
                'coupon_code' => $couponCode,
                'payment_method' => $input['payment_method'] ?? 'cod',
                'status' => 'pending'
            ]);

            foreach ($orderItemsData as $data) {
                $order->items()->create($data);
            }

            DB::commit();

            return response()->json([
                'status' => 200, 
                'message' => 'Đặt hàng thành công',
                'data' => ['redirect_url' => "/order/success/{$order->hash_id}"]
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error($e);
            return response()->json(['status' => 500, 'message' => 'Lỗi hệ thống: ' . $e->getMessage()], 500);
        }
    }
    
    // Giữ nguyên các hàm khác (getOrderByHash, index, show...)
    public function getOrderByHash($hash) { return response()->json(['status' => 200, 'data' => Order::with('items')->where('hash_id', $hash)->first()]); }
    public function index(Request $request) { return response()->json(['status' => 200, 'data' => Order::orderBy('created_at','desc')->paginate(10)]); }
    public function show($id) { return response()->json(['status' => 200, 'data' => Order::with('items.product')->find($id)]); }
}
EOF

# Thêm Route check-coupon
echo "🔗 Cập nhật Route..."
if ! grep -q "check-coupon" /var/www/lica-project/backend/Modules/Order/routes/api.php; then
    sed -i "/Route::post('\/checkout', \[OrderController::class, 'checkout'\]);/a \    Route::post('/check-coupon', [OrderController::class, 'checkCoupon']);" /var/www/lica-project/backend/Modules/Order/routes/api.php
fi

# ==============================================================================
# 3. FRONTEND: Cập nhật Shipping Page (UI Coupon)
# ==============================================================================
echo "💻 Cập nhật Frontend Shipping Page..."

cat << 'EOF' > /var/www/lica-project/apps/user/app/order/shipping/page.tsx
"use client";

import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { MapPin, Phone, User, Truck, Banknote, CreditCard, Loader2, Ticket } from "lucide-react";
import SmartLocationInput from "@/components/common/SmartLocationInput";

export default function ShippingPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [initializing, setInitializing] = useState(true);
  const [error, setError] = useState("");

  const [formData, setFormData] = useState({
    customer_name: "", customer_phone: "", customer_email: "",
    payment_method: "cash_on_delivery", note: ""
  });
  const [addressData, setAddressData] = useState({ street: "", province_code: "", district_code: "", ward_code: "" });
  const [fullLocationLabel, setFullLocationLabel] = useState("");
  const [locationNames, setLocationNames] = useState({ province: "", district: "", ward: "" });

  // Coupon State
  const [couponCode, setCouponCode] = useState("");
  const [appliedCoupon, setAppliedCoupon] = useState<{code: string, discount: number} | null>(null);
  const [checkingCoupon, setCheckingCoupon] = useState(false);
  const [couponMsg, setCouponMsg] = useState("");

  const cartItems = [{ product_id: 1, quantity: 1, name: "Sản phẩm Demo", price: 500000 }];
  const subTotal = cartItems.reduce((acc, item) => acc + (item.price * item.quantity), 0);
  const totalAmount = subTotal - (appliedCoupon?.discount || 0);

  useEffect(() => {
    const initData = async () => {
      try {
        const token = localStorage.getItem("token");
        if (token) {
            const apiUrl = process.env.NEXT_PUBLIC_API_URL;
            const [meRes, addrRes] = await Promise.all([
                axios.get(\`\${apiUrl}/api/v1/profile/me\`, { headers: { Authorization: \`Bearer \${token}\` } }),
                axios.get(\`\${apiUrl}/api/v1/profile/addresses\`, { headers: { Authorization: \`Bearer \${token}\` } })
            ]);
            const user = meRes.data.data;
            const addresses = addrRes.data.data;
            const defaultAddr = addresses.find((a: any) => a.is_default) || addresses[0];

            setFormData(prev => ({
                ...prev, customer_name: defaultAddr ? defaultAddr.name : user.name,
                customer_phone: defaultAddr ? defaultAddr.phone : (user.phone || ""), customer_email: user.email || ""
            }));

            if (defaultAddr && defaultAddr.province_id) {
                 setAddressData({ street: defaultAddr.address, province_code: defaultAddr.province_id, district_code: defaultAddr.district_id, ward_code: defaultAddr.ward_id });
                 try {
                     const [pRes, dRes, wRes] = await Promise.all([
                        axios.get(\`\${apiUrl}/api/v1/location/provinces\`),
                        axios.get(\`\${apiUrl}/api/v1/location/districts/\${defaultAddr.province_id}\`),
                        axios.get(\`\${apiUrl}/api/v1/location/wards/\${defaultAddr.district_id}\`)
                     ]);
                     const pName = pRes.data.data.find((x:any)=>x.code==defaultAddr.province_id)?.name;
                     const dName = dRes.data.data.find((x:any)=>x.code==defaultAddr.district_id)?.name;
                     const wName = wRes.data.data.find((x:any)=>x.code==defaultAddr.ward_id)?.name;
                     setFullLocationLabel(\`\${wName}, \${dName}, \${pName}\`);
                     setLocationNames({ province: pName, district: dName, ward: wName });
                 } catch(e) {}
            }
        }
      } catch (err) { console.log("Guest"); } finally { setInitializing(false); }
    };
    initData();
  }, []);

  const handleApplyCoupon = async () => {
    if(!couponCode.trim()) return;
    setCheckingCoupon(true);
    setCouponMsg("");
    try {
        const res = await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/check-coupon\`, {
            code: couponCode,
            items: cartItems.map(i => ({ product_id: i.product_id, quantity: i.quantity }))
        });
        setAppliedCoupon({ code: couponCode, discount: res.data.data.discount });
        setCouponMsg("Áp dụng mã thành công!");
    } catch (err: any) {
        setAppliedCoupon(null);
        setCouponMsg(err.response?.data?.message || "Mã không hợp lệ");
    } finally { setCheckingCoupon(false); }
  };

  const handleRemoveCoupon = () => {
    setAppliedCoupon(null);
    setCouponCode("");
    setCouponMsg("");
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    if (!addressData.province_code || !addressData.street) { setError("Vui lòng nhập địa chỉ đầy đủ."); setLoading(false); return; }

    try {
      const finalAddress = \`\${addressData.street}, \${locationNames.ward}, \${locationNames.district}, \${locationNames.province}\`;
      const token = localStorage.getItem("token");
      const headers = token ? { Authorization: \`Bearer \${token}\` } : {};
      
      const payload = {
        ...formData, shipping_address: finalAddress,
        coupon_code: appliedCoupon ? appliedCoupon.code : null, // Gửi mã giảm giá lên
        items: cartItems.map(i => ({ product_id: i.product_id, quantity: i.quantity }))
      };

      const res = await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/checkout\`, payload, { headers });
      if (res.data.status === 200) router.push(res.data.data.redirect_url);
    } catch (err: any) { setError(err.response?.data?.message || "Lỗi đặt hàng"); } finally { setLoading(false); }
  };

  if (initializing) return <div className="h-screen flex justify-center items-center"><Loader2 className="animate-spin text-blue-600"/></div>;

  return (
    <div className="min-h-screen bg-gray-50 p-4 font-sans">
      <div className="max-w-4xl mx-auto bg-white shadow rounded-xl overflow-hidden">
        <div className="bg-gradient-to-r from-blue-700 to-blue-600 p-4 text-white font-bold flex gap-2 items-center">
            <MapPin size={20}/> Thông tin giao hàng
        </div>
        <div className="p-6 grid md:grid-cols-3 gap-8">
            <form onSubmit={handleSubmit} className="md:col-span-2 space-y-6">
                <div className="grid grid-cols-2 gap-4">
                    <div><label className="text-sm font-medium mb-1 block">Họ tên *</label><div className="relative"><User size={16} className="absolute left-3 top-3 text-gray-400"/><input className="w-full border rounded-lg pl-9 p-2.5" value={formData.customer_name} onChange={e => setFormData({...formData, customer_name: e.target.value})} required /></div></div>
                    <div><label className="text-sm font-medium mb-1 block">SĐT *</label><div className="relative"><Phone size={16} className="absolute left-3 top-3 text-gray-400"/><input className="w-full border rounded-lg pl-9 p-2.5" value={formData.customer_phone} onChange={e => setFormData({...formData, customer_phone: e.target.value})} required /></div></div>
                </div>

                <div className="bg-blue-50/50 p-5 rounded-xl border border-blue-100">
                    <h3 className="text-sm font-bold uppercase mb-3 flex items-center gap-2"><Truck size={16}/> Địa chỉ</h3>
                    <div className="mb-3"><label className="text-xs font-medium text-gray-500 mb-1 block">Khu vực *</label><SmartLocationInput onSelect={(d) => { setAddressData(p=>({...p, province_code: d.province_code, district_code: d.district_code, ward_code: d.ward_code})); setFullLocationLabel(d.label); setLocationNames({province: d.province_name, district: d.district_name, ward: d.ward_name}); }} initialLabel={fullLocationLabel} /></div>
                    <div><label className="text-xs font-medium text-gray-500 mb-1 block">Chi tiết *</label><input className="w-full border rounded-lg p-2.5 text-sm" placeholder="Số nhà..." value={addressData.street} onChange={e => setAddressData({...addressData, street: e.target.value})} required /></div>
                </div>

                <div><label className="text-sm font-medium mb-1 block">Ghi chú</label><textarea className="w-full border rounded-lg p-3 text-sm" rows={2} value={formData.note} onChange={e => setFormData({...formData, note: e.target.value})}></textarea></div>

                <div>
                    <label className="text-sm font-medium mb-2 block">Thanh toán</label>
                    <div className="grid grid-cols-2 gap-3">
                        <label className={\`border rounded-lg p-4 flex items-center gap-2 cursor-pointer \${formData.payment_method==='cash_on_delivery'?'border-blue-600 bg-blue-50 ring-1 ring-blue-600':''}\`}><input type="radio" name="pay" value="cash_on_delivery" checked={formData.payment_method==='cash_on_delivery'} onChange={e=>setFormData({...formData, payment_method: e.target.value})} className="accent-blue-600"/><Banknote size={20} className="text-green-600"/><span className="text-sm font-medium">COD</span></label>
                        <label className={\`border rounded-lg p-4 flex items-center gap-2 cursor-pointer \${formData.payment_method==='banking'?'border-blue-600 bg-blue-50 ring-1 ring-blue-600':''}\`}><input type="radio" name="pay" value="banking" checked={formData.payment_method==='banking'} onChange={e=>setFormData({...formData, payment_method: e.target.value})} className="accent-blue-600"/><CreditCard size={20} className="text-blue-600"/><span className="text-sm font-medium">Chuyển khoản</span></label>
                    </div>
                </div>
                
                {error && <div className="bg-red-50 text-red-600 p-3 rounded text-sm">{error}</div>}
                <button type="submit" disabled={loading} className="w-full bg-red-600 text-white font-bold py-4 rounded-lg hover:bg-red-700 shadow-lg shadow-red-200 uppercase">{loading ? "Đang xử lý..." : \`ĐẶT HÀNG NGAY (\${new Intl.NumberFormat('vi-VN').format(totalAmount)}đ)\`}</button>
            </form>

            <div className="h-fit space-y-4">
                <div className="bg-gray-50 p-5 rounded-xl border border-gray-200">
                    <h2 className="font-bold border-b pb-3 mb-4 text-sm uppercase">Đơn hàng</h2>
                    <div className="space-y-3 max-h-60 overflow-y-auto pr-1">
                        {cartItems.map((i, idx) => <div key={idx} className="flex justify-between text-sm"><span>{i.name} x{i.quantity}</span><span className="font-medium">{new Intl.NumberFormat('vi-VN').format(i.price * i.quantity)}đ</span></div>)}
                    </div>
                    
                    {/* COUPON INPUT */}
                    <div className="border-t border-dashed border-gray-300 pt-4 mt-4">
                        <label className="text-xs font-bold text-gray-500 uppercase mb-2 block flex items-center gap-1"><Ticket size={14}/> Mã giảm giá</label>
                        <div className="flex gap-2">
                            <input type="text" placeholder="Nhập mã" className="flex-1 border rounded p-2 text-sm uppercase font-bold text-gray-700" 
                                value={couponCode} onChange={e => setCouponCode(e.target.value.toUpperCase())} disabled={!!appliedCoupon} />
                            {appliedCoupon ? (
                                <button type="button" onClick={handleRemoveCoupon} className="bg-gray-200 text-gray-600 px-3 py-2 rounded text-sm font-bold hover:bg-gray-300">Xóa</button>
                            ) : (
                                <button type="button" onClick={handleApplyCoupon} disabled={checkingCoupon} className="bg-blue-600 text-white px-3 py-2 rounded text-sm font-bold hover:bg-blue-700 disabled:opacity-70">Áp dụng</button>
                            )}
                        </div>
                        {couponMsg && <div className={\`text-xs mt-2 \${appliedCoupon ? 'text-green-600' : 'text-red-600'}\`}>{couponMsg}</div>}
                    </div>

                    <div className="border-t border-gray-300 pt-4 mt-4 space-y-2">
                        <div className="flex justify-between text-sm text-gray-600"><span>Tạm tính</span><span>{new Intl.NumberFormat('vi-VN').format(subTotal)}đ</span></div>
                        {appliedCoupon && (
                            <div className="flex justify-between text-sm text-green-600 font-medium">
                                <span>Giảm giá ({appliedCoupon.code})</span>
                                <span>-{new Intl.NumberFormat('vi-VN').format(appliedCoupon.discount)}đ</span>
                            </div>
                        )}
                        <div className="flex justify-between text-sm text-gray-600"><span>Phí vận chuyển</span><span className="text-green-600 font-medium">Miễn phí</span></div>
                    </div>
                    <div className="border-t border-gray-300 pt-4 mt-4 flex justify-between font-bold text-xl text-red-600">
                        <span>Tổng cộng</span>
                        <span>{new Intl.NumberFormat('vi-VN').format(totalAmount)}đ</span>
                    </div>
                </div>
            </div>
        </div>
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# 4. BUILD
# ==============================================================================
echo "🔄 Clear Cache & Build..."
cd /var/www/lica-project/backend
php artisan route:clear

cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Hoàn tất! Vào đặt hàng và thử nhập mã giảm giá."
