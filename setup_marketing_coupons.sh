#!/bin/bash

echo "🚀 Đang xây dựng Kênh Marketing: Mã giảm giá & Chọn sản phẩm..."

# ==============================================================================
# 1. BACKEND: Database & Model
# ==============================================================================
echo "📦 Tạo Migration Coupons..."

cd /var/www/lica-project/backend

TIMESTAMP=$(date +"%Y_%m_%d_%H%M%S")
cat << EOF > Modules/Order/database/migrations/${TIMESTAMP}_create_coupons_table.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Bảng Mã giảm giá
        if (!Schema::hasTable('coupons')) {
            Schema::create('coupons', function (Blueprint \$table) {
                \$table->id();
                \$table->string('code')->unique(); // Mã: SALE50
                \$table->string('name'); // Tên: Giảm giá 50k
                \$table->string('type')->default('fixed'); // fixed (tiền) hoặc percent (%)
                \$table->decimal('value', 15, 2); // Giá trị giảm
                \$table->decimal('min_order_value', 15, 2)->default(0); // Đơn tối thiểu
                \$table->integer('usage_limit')->default(0); // Giới hạn số lượng
                \$table->integer('used_count')->default(0); // Đã dùng
                \$table->timestamp('start_date')->nullable();
                \$table->timestamp('end_date')->nullable();
                \$table->boolean('is_active')->default(true);
                \$table->string('apply_type')->default('all'); // all (toàn shop) hoặc specific (sản phẩm cụ thể)
                \$table->timestamps();
            });
        }

        // Bảng trung gian: Mã giảm giá áp dụng cho Sản phẩm nào
        if (!Schema::hasTable('coupon_product')) {
            Schema::create('coupon_product', function (Blueprint \$table) {
                \$table->id();
                \$table->foreignId('coupon_id')->constrained()->onDelete('cascade');
                \$table->foreignId('product_id')->constrained()->onDelete('cascade');
                \$table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('coupon_product');
        Schema::dropIfExists('coupons');
    }
};
EOF

echo "📝 Tạo Model Coupon..."
cat << 'EOF' > Modules/Order/app/Models/Coupon.php
<?php

namespace Modules\Order\Models;

use Illuminate\Database\Eloquent\Model;
use Modules\Product\Models\Product;

class Coupon extends Model
{
    protected $guarded = [];

    // Quan hệ Many-to-Many với Sản phẩm
    public function products()
    {
        return $this->belongsToMany(Product::class, 'coupon_product');
    }
}
EOF

# ==============================================================================
# 2. BACKEND: CouponController
# ==============================================================================
echo "⚙️ Tạo CouponController..."

cat << 'EOF' > Modules/Order/app/Http/Controllers/CouponController.php
<?php

namespace Modules\Order\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Order\Models\Coupon;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;

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

            // Lưu danh sách sản phẩm áp dụng
            if ($request->has('product_ids') && !empty($request->product_ids)) {
                $coupon->products()->sync($request->product_ids);
            }

            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Tạo mã giảm giá thành công']);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }

    public function show($id)
    {
        $coupon = Coupon::with('products:id,name,thumbnail,sku')->find($id);
        return response()->json(['status' => 200, 'data' => $coupon]);
    }

    public function destroy($id)
    {
        Coupon::destroy($id);
        return response()->json(['status' => 200, 'message' => 'Đã xóa']);
    }
}
EOF

# Thêm Route
echo "🔗 Cập nhật Route..."
cat << 'EOF' >> Modules/Order/routes/api.php

use Modules\Order\Http\Controllers\CouponController;

Route::prefix('v1/marketing/coupons')->group(function () {
    Route::get('/', [CouponController::class, 'index']);
    Route::post('/', [CouponController::class, 'store']);
    Route::get('/{id}', [CouponController::class, 'show']);
    Route::delete('/{id}', [CouponController::class, 'destroy']);
});
EOF

# ==============================================================================
# 3. FRONTEND: Component ProductSelector (Modal chọn sản phẩm)
# ==============================================================================
echo "💻 Tạo Component Chọn sản phẩm (Modal)..."
mkdir -p /var/www/lica-project/apps/admin/components/marketing

cat << 'EOF' > /var/www/lica-project/apps/admin/components/marketing/ProductSelector.tsx
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { Search, CheckSquare, Square, X, Loader2 } from "lucide-react";

interface Product { id: number; name: string; thumbnail: string; sku: string; price: number; }

interface Props {
  selectedIds: number[];
  onChange: (ids: number[]) => void;
  onClose: () => void;
}

export default function ProductSelector({ selectedIds, onChange, onClose }: Props) {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState("");
  const [localSelected, setLocalSelected] = useState<number[]>(selectedIds);

  useEffect(() => {
    fetchProducts();
  }, [search]);

  const fetchProducts = async () => {
    setLoading(true);
    try {
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product`, {
            params: { q: search, limit: 20 } // Limit nhỏ để load nhanh
        });
        setProducts(res.data.data.data);
    } catch (e) { console.error(e); } finally { setLoading(false); }
  };

  const toggleSelect = (id: number) => {
    setLocalSelected(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]);
  };

  const handleConfirm = () => {
    onChange(localSelected);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl w-full max-w-2xl h-[80vh] flex flex-col shadow-2xl">
        {/* Header */}
        <div className="p-4 border-b flex justify-between items-center bg-gray-50 rounded-t-xl">
            <h3 className="font-bold text-lg">Chọn sản phẩm áp dụng</h3>
            <button onClick={onClose}><X className="text-gray-500 hover:text-red-500"/></button>
        </div>

        {/* Search */}
        <div className="p-4 border-b">
            <div className="relative">
                <Search className="absolute left-3 top-2.5 text-gray-400" size={18}/>
                <input type="text" placeholder="Tìm tên sản phẩm, SKU..." className="w-full pl-10 border rounded p-2 outline-none focus:ring-2 focus:ring-blue-500"
                    value={search} onChange={e => setSearch(e.target.value)} />
            </div>
        </div>

        {/* List */}
        <div className="flex-1 overflow-y-auto p-2">
            {loading ? <div className="text-center p-10"><Loader2 className="animate-spin inline"/></div> : (
                <div className="space-y-1">
                    {products.map(p => {
                        const isSelected = localSelected.includes(p.id);
                        return (
                            <div key={p.id} onClick={() => toggleSelect(p.id)} 
                                className={`flex items-center gap-3 p-3 rounded-lg cursor-pointer transition border ${isSelected ? 'bg-blue-50 border-blue-200' : 'hover:bg-gray-50 border-transparent'}`}>
                                {isSelected ? <CheckSquare className="text-blue-600 shrink-0"/> : <Square className="text-gray-400 shrink-0"/>}
                                <img src={p.thumbnail} className="w-10 h-10 object-cover rounded border bg-white" />
                                <div>
                                    <div className="font-medium line-clamp-1">{p.name}</div>
                                    <div className="text-xs text-gray-500">SKU: {p.sku} | {new Intl.NumberFormat('vi-VN').format(p.price)}đ</div>
                                </div>
                            </div>
                        )
                    })}
                </div>
            )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t flex justify-between items-center bg-gray-50 rounded-b-xl">
            <span className="text-sm font-medium">Đã chọn: <b className="text-blue-600">{localSelected.length}</b> sản phẩm</span>
            <div className="flex gap-2">
                <button onClick={onClose} className="px-4 py-2 border rounded hover:bg-gray-100">Hủy</button>
                <button onClick={handleConfirm} className="px-6 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 font-bold">Xác nhận</button>
            </div>
        </div>
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# 4. FRONTEND: Trang Quản lý Coupon (List & Create)
# ==============================================================================
echo "💻 Tạo trang Quản lý Mã giảm giá..."
mkdir -p /var/www/lica-project/apps/admin/app/marketing/coupons/create

# 4.1 Trang Danh sách
cat << 'EOF' > /var/www/lica-project/apps/admin/app/marketing/coupons/page.tsx
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import Link from "next/link";
import { Plus, Ticket, Trash2, Calendar, Search } from "lucide-react";

export default function CouponListPage() {
  const [coupons, setCoupons] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/marketing/coupons`)
         .then(res => setCoupons(res.data.data.data))
         .finally(() => setLoading(false));
  }, []);

  const handleDelete = async (id: number) => {
    if(!confirm("Xóa mã này?")) return;
    await axios.delete(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/marketing/coupons/${id}`);
    setCoupons(prev => prev.filter(c => c.id !== id));
  };

  return (
    <div className="p-6 bg-gray-50 min-h-screen">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2"><Ticket/> Mã Giảm Giá</h1>
        <Link href="/marketing/coupons/create" className="bg-blue-600 text-white px-4 py-2 rounded-lg font-bold flex items-center gap-2 hover:bg-blue-700">
            <Plus size={18}/> Tạo Mã Mới
        </Link>
      </div>

      <div className="bg-white rounded-xl shadow border overflow-hidden">
        <table className="w-full text-left text-sm">
            <thead className="bg-gray-100 text-gray-600 uppercase text-xs">
                <tr>
                    <th className="p-4">Mã Voucher</th>
                    <th className="p-4">Tên chương trình</th>
                    <th className="p-4">Giảm giá</th>
                    <th className="p-4">Thời gian</th>
                    <th className="p-4">Phạm vi</th>
                    <th className="p-4 text-right">Thao tác</th>
                </tr>
            </thead>
            <tbody className="divide-y">
                {loading ? <tr><td colSpan={6} className="p-10 text-center">Đang tải...</td></tr> : coupons.map(c => (
                    <tr key={c.id} className="hover:bg-gray-50">
                        <td className="p-4 font-bold text-blue-600">{c.code}</td>
                        <td className="p-4">{c.name}</td>
                        <td className="p-4 font-medium text-red-600">
                            {c.type === 'fixed' ? '-' + new Intl.NumberFormat('vi-VN').format(c.value) + 'đ' : '-' + c.value + '%'}
                        </td>
                        <td className="p-4 text-gray-500 text-xs">
                            <div>{new Date(c.start_date).toLocaleDateString()}</div>
                            <div>{new Date(c.end_date).toLocaleDateString()}</div>
                        </td>
                        <td className="p-4">
                            {c.products_count > 0 ? <span className="bg-purple-100 text-purple-700 px-2 py-1 rounded text-xs">SP Cụ thể ({c.products_count})</span> : <span className="bg-green-100 text-green-700 px-2 py-1 rounded text-xs">Toàn Shop</span>}
                        </td>
                        <td className="p-4 text-right">
                            <button onClick={() => handleDelete(c.id)} className="text-gray-400 hover:text-red-600"><Trash2 size={18}/></button>
                        </td>
                    </tr>
                ))}
            </tbody>
        </table>
      </div>
    </div>
  );
}
EOF

# 4.2 Trang Tạo mới
cat << 'EOF' > /var/www/lica-project/apps/admin/app/marketing/coupons/create/page.tsx
"use client";
import { useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, Save, Plus } from "lucide-react";
import ProductSelector from "@/components/marketing/ProductSelector";

export default function CreateCouponPage() {
  const router = useRouter();
  const [form, setForm] = useState({
    name: "", code: "", type: "fixed", value: 0, min_order_value: 0, usage_limit: 100,
    start_date: "", end_date: "", product_ids: [] as number[]
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
    } catch (err: any) {
        alert(err.response?.data?.message || "Lỗi tạo mã");
    } finally { setLoading(false); }
  };

  return (
    <div className="p-6 bg-gray-50 min-h-screen pb-20">
      <form onSubmit={handleSubmit} className="max-w-4xl mx-auto">
        <div className="flex items-center gap-4 mb-6">
            <Link href="/marketing/coupons" className="p-2 border rounded hover:bg-white"><ArrowLeft size={20}/></Link>
            <h1 className="text-2xl font-bold">Tạo Mã Giảm Giá Mới</h1>
        </div>

        <div className="space-y-6">
            {/* 1. Thông tin cơ bản */}
            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <h3 className="font-bold border-b pb-3 mb-4">Thông tin cơ bản</h3>
                <div className="grid grid-cols-2 gap-4 mb-4">
                    <div>
                        <label className="block text-sm font-medium mb-1">Tên chương trình</label>
                        <input className="w-full border rounded p-2" required value={form.name} onChange={e => setForm({...form, name: e.target.value})} placeholder="VD: Sale Tết 2026"/>
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-1">Mã Voucher (Tối đa 20 ký tự)</label>
                        <input className="w-full border rounded p-2 uppercase" required value={form.code} onChange={e => setForm({...form, code: e.target.value.toUpperCase()})} placeholder="VD: TET2026"/>
                    </div>
                </div>
                <div className="grid grid-cols-2 gap-4">
                    <div>
                        <label className="block text-sm font-medium mb-1">Thời gian bắt đầu</label>
                        <input type="datetime-local" className="w-full border rounded p-2" required onChange={e => setForm({...form, start_date: e.target.value})}/>
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-1">Thời gian kết thúc</label>
                        <input type="datetime-local" className="w-full border rounded p-2" required onChange={e => setForm({...form, end_date: e.target.value})}/>
                    </div>
                </div>
            </div>

            {/* 2. Thiết lập giảm giá */}
            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <h3 className="font-bold border-b pb-3 mb-4">Thiết lập giảm giá</h3>
                <div className="grid grid-cols-3 gap-4 mb-4">
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
                    <div>
                        <label className="block text-sm font-medium mb-1">Đơn tối thiểu</label>
                        <input type="number" className="w-full border rounded p-2" required value={form.min_order_value} onChange={e => setForm({...form, min_order_value: Number(e.target.value)})}/>
                    </div>
                </div>
                <div>
                    <label className="block text-sm font-medium mb-1">Tổng lượt sử dụng tối đa</label>
                    <input type="number" className="w-full border rounded p-2" required value={form.usage_limit} onChange={e => setForm({...form, usage_limit: Number(e.target.value)})}/>
                </div>
            </div>

            {/* 3. Sản phẩm áp dụng */}
            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <h3 className="font-bold border-b pb-3 mb-4">Sản phẩm áp dụng</h3>
                <div className="mb-4">
                    <label className="flex items-center gap-2 mb-2">
                        <input type="radio" name="apply" checked={form.product_ids.length === 0} onChange={() => setForm({...form, product_ids: []})} />
                        <span>Toàn bộ sản phẩm</span>
                    </label>
                    <label className="flex items-center gap-2">
                        <input type="radio" name="apply" checked={form.product_ids.length > 0} onChange={() => setShowProductModal(true)} />
                        <span>Sản phẩm nhất định</span>
                    </label>
                </div>

                {form.product_ids.length > 0 && (
                    <div className="p-4 bg-blue-50 border border-blue-100 rounded-lg">
                        <div className="flex justify-between items-center mb-2">
                            <span className="font-bold text-blue-800">Đã chọn {form.product_ids.length} sản phẩm</span>
                            <button type="button" onClick={() => setShowProductModal(true)} className="text-sm text-blue-600 underline">Chỉnh sửa</button>
                        </div>
                        <p className="text-xs text-gray-500">Mã giảm giá này sẽ chỉ áp dụng khi khách hàng mua các sản phẩm đã chọn.</p>
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

      {/* PRODUCT SELECTOR MODAL */}
      {showProductModal && (
        <ProductSelector 
            selectedIds={form.product_ids} 
            onChange={(ids) => setForm({...form, product_ids: ids})} 
            onClose={() => setShowProductModal(false)} 
        />
      )}
    </div>
  );
}
EOF

# ==============================================================================
# 5. RUN
# ==============================================================================
echo "🔄 Chạy Migration & Build..."
cd /var/www/lica-project/backend
php artisan migrate --force
php artisan route:clear

cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Hoàn tất! Truy cập https://admin.lica.vn/marketing/coupons để trải nghiệm."
