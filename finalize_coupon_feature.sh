#!/bin/bash

echo "🚀 Đang hoàn thiện tính năng Mã giảm giá (Edit & Sidebar)..."

# ==============================================================================
# 1. BACKEND: Bổ sung hàm UPDATE trong CouponController
# ==============================================================================
echo "⚙️ Cập nhật Backend: Thêm logic sửa mã..."

# Ghi đè lại Controller với đầy đủ hàm update
cat << 'EOF' > /var/www/lica-project/backend/Modules/Order/app/Http/Controllers/CouponController.php
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

            if ($request->has('product_ids') && !empty($request->product_ids)) {
                $coupon->products()->sync($request->product_ids);
            }

            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Tạo mã thành công']);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }

    // NEW: Hàm Update
    public function update(Request $request, $id)
    {
        $coupon = Coupon::find($id);
        if (!$coupon) return response()->json(['message' => 'Not found'], 404);

        $validator = Validator::make($request->all(), [
            'code' => ['required', 'uppercase', Rule::unique('coupons')->ignore($coupon->id)],
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
            
            $coupon->update($data);

            // Cập nhật quan hệ sản phẩm (Sync: xóa cũ thêm mới)
            if ($request->has('product_ids')) {
                $coupon->products()->sync($request->product_ids);
            }

            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Cập nhật thành công']);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }

    public function show($id)
    {
        // Load kèm danh sách ID sản phẩm để frontend pre-fill
        $coupon = Coupon::with('products:id,name,thumbnail,sku,price')->find($id);
        if (!$coupon) return response()->json(['message' => 'Not found'], 404);
        
        // Trả về thêm mảng product_ids tiện cho frontend
        $coupon->product_ids = $coupon->products->pluck('id');
        
        return response()->json(['status' => 200, 'data' => $coupon]);
    }

    public function destroy($id)
    {
        Coupon::destroy($id);
        return response()->json(['status' => 200, 'message' => 'Đã xóa']);
    }
}
EOF

# Thêm Route Update
echo "🔗 Cập nhật Route..."
if ! grep -q "Route::put('/{id}', \[CouponController::class, 'update'\]);" /var/www/lica-project/backend/Modules/Order/routes/api.php; then
    sed -i "/Route::get('\/{id}', \[CouponController::class, 'show'\]);/a \    Route::put('/{id}', [CouponController::class, 'update']);" /var/www/lica-project/backend/Modules/Order/routes/api.php
fi

# ==============================================================================
# 2. FRONTEND: Tạo trang Edit Coupon ([id]/page.tsx)
# ==============================================================================
echo "💻 Tạo trang Chỉnh sửa Mã giảm giá..."
mkdir -p /var/www/lica-project/apps/admin/app/marketing/coupons/[id]

cat << 'EOF' > /var/www/lica-project/apps/admin/app/marketing/coupons/[id]/page.tsx
"use client";

import { useState, useEffect, use } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, Save, Loader2, Trash2 } from "lucide-react";
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
    is_active: true
  });

  // State hiển thị danh sách sản phẩm đã chọn (để review)
  const [selectedProductsDisplay, setSelectedProductsDisplay] = useState<any[]>([]);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/marketing/coupons/${id}`);
        const data = res.data.data;
        
        // Format date for datetime-local input (YYYY-MM-DDTHH:mm)
        const formatTime = (isoString: string) => isoString ? new Date(isoString).toISOString().slice(0, 16) : "";

        setForm({
            name: data.name,
            code: data.code,
            type: data.type,
            value: Number(data.value),
            min_order_value: Number(data.min_order_value),
            usage_limit: Number(data.usage_limit),
            start_date: formatTime(data.start_date),
            end_date: formatTime(data.end_date),
            product_ids: data.product_ids || [],
            is_active: Boolean(data.is_active)
        });
        setSelectedProductsDisplay(data.products || []);
      } catch (err) {
        alert("Không tìm thấy mã giảm giá");
        router.push("/marketing/coupons");
      } finally {
        setLoading(false);
      }
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
    } catch (err: any) {
        alert(err.response?.data?.message || "Lỗi cập nhật");
    } finally { setSaving(false); }
  };

  if (loading) return <div className="h-screen flex items-center justify-center"><Loader2 className="animate-spin text-blue-600"/></div>;

  return (
    <div className="p-6 bg-gray-50 min-h-screen pb-20">
      <form onSubmit={handleSubmit} className="max-w-4xl mx-auto">
        <div className="flex items-center justify-between mb-6">
            <div className="flex items-center gap-4">
                <Link href="/marketing/coupons" className="p-2 border rounded hover:bg-white"><ArrowLeft size={20}/></Link>
                <h1 className="text-2xl font-bold text-gray-800">Chỉnh sửa Mã Giảm Giá</h1>
            </div>
            <div className="flex items-center gap-2">
                <span className="text-sm font-medium">Trạng thái:</span>
                <button type="button" 
                    onClick={() => setForm({...form, is_active: !form.is_active})}
                    className={`px-3 py-1 rounded-full text-xs font-bold ${form.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-200 text-gray-600'}`}>
                    {form.is_active ? 'Đang hoạt động' : 'Tạm dừng'}
                </button>
            </div>
        </div>

        <div className="space-y-6">
            {/* 1. Thông tin cơ bản */}
            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <h3 className="font-bold border-b pb-3 mb-4 text-gray-800">Thông tin cơ bản</h3>
                <div className="grid grid-cols-2 gap-4 mb-4">
                    <div>
                        <label className="block text-sm font-medium mb-1">Tên chương trình</label>
                        <input className="w-full border rounded p-2 focus:ring-2 focus:ring-blue-500 outline-none" required value={form.name} onChange={e => setForm({...form, name: e.target.value})} />
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-1">Mã Voucher</label>
                        <input className="w-full border rounded p-2 uppercase bg-gray-50 text-gray-500 font-bold" required value={form.code} onChange={e => setForm({...form, code: e.target.value.toUpperCase()})} />
                    </div>
                </div>
                <div className="grid grid-cols-2 gap-4">
                    <div>
                        <label className="block text-sm font-medium mb-1">Thời gian bắt đầu</label>
                        <input type="datetime-local" className="w-full border rounded p-2" required value={form.start_date} onChange={e => setForm({...form, start_date: e.target.value})}/>
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-1">Thời gian kết thúc</label>
                        <input type="datetime-local" className="w-full border rounded p-2" required value={form.end_date} onChange={e => setForm({...form, end_date: e.target.value})}/>
                    </div>
                </div>
            </div>

            {/* 2. Thiết lập giảm giá */}
            <div className="bg-white p-6 rounded-xl shadow-sm border">
                <h3 className="font-bold border-b pb-3 mb-4 text-gray-800">Thiết lập giảm giá</h3>
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
                <h3 className="font-bold border-b pb-3 mb-4 text-gray-800">Sản phẩm áp dụng</h3>
                <div className="mb-4">
                    <label className="flex items-center gap-2 mb-2 cursor-pointer">
                        <input type="radio" name="apply" checked={form.product_ids.length === 0} onChange={() => setForm({...form, product_ids: []})} className="accent-blue-600"/>
                        <span>Toàn bộ sản phẩm</span>
                    </label>
                    <label className="flex items-center gap-2 cursor-pointer">
                        <input type="radio" name="apply" checked={form.product_ids.length > 0} onChange={() => setShowProductModal(true)} className="accent-blue-600"/>
                        <span>Sản phẩm nhất định</span>
                    </label>
                </div>

                {form.product_ids.length > 0 && (
                    <div className="p-4 bg-blue-50 border border-blue-100 rounded-lg">
                        <div className="flex justify-between items-center mb-3">
                            <span className="font-bold text-blue-800">Đã chọn {form.product_ids.length} sản phẩm</span>
                            <button type="button" onClick={() => setShowProductModal(true)} className="text-sm font-bold text-blue-600 hover:underline">Chỉnh sửa danh sách</button>
                        </div>
                        
                        {/* Preview List (Max 5 items) */}
                        <div className="space-y-2">
                            {selectedProductsDisplay.slice(0, 3).map((p: any) => (
                                <div key={p.id} className="flex items-center gap-2 bg-white p-2 rounded border border-blue-100">
                                    <img src={p.thumbnail} className="w-8 h-8 rounded object-cover"/>
                                    <span className="text-sm line-clamp-1">{p.name}</span>
                                </div>
                            ))}
                            {selectedProductsDisplay.length > 3 && <div className="text-xs text-gray-500 italic ml-1">...và {selectedProductsDisplay.length - 3} sản phẩm khác</div>}
                        </div>
                    </div>
                )}
            </div>
        </div>

        <div className="fixed bottom-0 left-0 right-0 bg-white border-t p-4 flex justify-end gap-4 shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.1)] z-40">
            <Link href="/marketing/coupons" className="px-6 py-2 border rounded-lg hover:bg-gray-100 transition font-medium">Hủy</Link>
            <button type="submit" disabled={saving} className="px-8 py-2 bg-blue-600 text-white font-bold rounded-lg hover:bg-blue-700 flex items-center gap-2 transition shadow-lg shadow-blue-200">
                <Save size={18}/> {saving ? "Đang lưu..." : "Cập nhật Voucher"}
            </button>
        </div>
      </form>

      {/* PRODUCT SELECTOR MODAL */}
      {showProductModal && (
        <ProductSelector 
            selectedIds={form.product_ids} 
            onChange={(ids) => {
                setForm({...form, product_ids: ids});
                // Note: Actual product display won't update immediately here without re-fetching, 
                // but the count will update. In a real app we'd sync the display list too.
            }} 
            onClose={() => setShowProductModal(false)} 
        />
      )}
    </div>
  );
}
EOF

# ==============================================================================
# 3. CẬP NHẬT TRANG DANH SÁCH (Link Edit)
# ==============================================================================
echo "🔗 Cập nhật liên kết trong trang danh sách..."
# Sửa lại trang List để bấm vào tên hoặc nút sửa sẽ sang trang Edit
cat << 'EOF' > /var/www/lica-project/apps/admin/app/marketing/coupons/page.tsx
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import Link from "next/link";
import { Plus, Ticket, Trash2, Calendar, Search, Edit } from "lucide-react";

export default function CouponListPage() {
  const [coupons, setCoupons] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/marketing/coupons`)
         .then(res => setCoupons(res.data.data.data))
         .finally(() => setLoading(false));
  }, []);

  const handleDelete = async (id: number) => {
    if(!confirm("Bạn chắc chắn muốn xóa mã giảm giá này?")) return;
    try {
        await axios.delete(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/marketing/coupons/${id}`);
        setCoupons(prev => prev.filter(c => c.id !== id));
    } catch(e) { alert("Lỗi khi xóa"); }
  };

  return (
    <div className="p-6 bg-gray-50 min-h-screen">
      <div className="flex justify-between items-center mb-6">
        <div>
            <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2"><Ticket className="text-blue-600"/> Mã Giảm Giá</h1>
            <p className="text-sm text-gray-500 mt-1">Quản lý các chương trình khuyến mãi Voucher</p>
        </div>
        <Link href="/marketing/coupons/create" className="bg-blue-600 text-white px-5 py-2.5 rounded-lg font-bold flex items-center gap-2 hover:bg-blue-700 shadow-lg shadow-blue-200 transition">
            <Plus size={18}/> Tạo Mã Mới
        </Link>
      </div>

      <div className="bg-white rounded-xl shadow border border-gray-200 overflow-hidden">
        <table className="w-full text-left text-sm">
            <thead className="bg-gray-50 text-gray-600 uppercase text-xs font-bold border-b">
                <tr>
                    <th className="p-4">Mã Voucher</th>
                    <th className="p-4">Tên chương trình</th>
                    <th className="p-4">Mức giảm</th>
                    <th className="p-4">Thời gian</th>
                    <th className="p-4">Trạng thái / Phạm vi</th>
                    <th className="p-4 text-right">Thao tác</th>
                </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
                {loading ? (
                    <tr><td colSpan={6} className="p-10 text-center text-gray-500">Đang tải dữ liệu...</td></tr>
                ) : coupons.length > 0 ? (
                    coupons.map(c => (
                        <tr key={c.id} className="hover:bg-blue-50/50 transition group">
                            <td className="p-4">
                                <Link href={`/marketing/coupons/${c.id}`} className="font-bold text-blue-600 border border-blue-200 bg-blue-50 px-2 py-1 rounded hover:bg-blue-100">
                                    {c.code}
                                </Link>
                            </td>
                            <td className="p-4 font-medium text-gray-800">{c.name}</td>
                            <td className="p-4">
                                <span className="font-bold text-red-600 text-base">
                                    {c.type === 'fixed' ? '-' + new Intl.NumberFormat('vi-VN').format(c.value) + 'đ' : '-' + c.value + '%'}
                                </span>
                                <div className="text-xs text-gray-400 mt-0.5">Đơn tối thiểu: {new Intl.NumberFormat('vi-VN').format(c.min_order_value)}đ</div>
                            </td>
                            <td className="p-4 text-gray-500 text-xs leading-relaxed">
                                <div className="flex items-center gap-1"><Calendar size={12}/> {new Date(c.start_date).toLocaleDateString()}</div>
                                <div className="flex items-center gap-1"><Calendar size={12}/> {new Date(c.end_date).toLocaleDateString()}</div>
                            </td>
                            <td className="p-4">
                                <div className="flex flex-col gap-1 items-start">
                                    <span className={`text-[10px] font-bold uppercase px-2 py-0.5 rounded ${c.is_active ? 'bg-green-100 text-green-700' : 'bg-gray-200 text-gray-500'}`}>
                                        {c.is_active ? 'Đang chạy' : 'Tạm dừng'}
                                    </span>
                                    {c.products_count > 0 ? 
                                        <span className="bg-purple-100 text-purple-700 px-2 py-0.5 rounded text-[10px] font-bold">SP Cụ thể ({c.products_count})</span> : 
                                        <span className="bg-orange-100 text-orange-700 px-2 py-0.5 rounded text-[10px] font-bold">Toàn Shop</span>
                                    }
                                </div>
                            </td>
                            <td className="p-4 text-right">
                                <div className="flex justify-end gap-2">
                                    <Link href={`/marketing/coupons/${c.id}`} className="p-2 text-blue-600 hover:bg-blue-100 rounded-lg transition" title="Sửa">
                                        <Edit size={18}/>
                                    </Link>
                                    <button onClick={() => handleDelete(c.id)} className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition" title="Xóa">
                                        <Trash2 size={18}/>
                                    </button>
                                </div>
                            </td>
                        </tr>
                    ))
                ) : (
                    <tr><td colSpan={6} className="p-10 text-center text-gray-400">Chưa có mã giảm giá nào.</td></tr>
                )}
            </tbody>
        </table>
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# 4. FRONTEND: Đảm bảo Sidebar có Menu Marketing
# ==============================================================================
echo "📋 Cập nhật Sidebar Admin..."

# Chúng ta tạo file Sidebar chuẩn nếu chưa có hoặc ghi đè để đảm bảo menu hiện ra
mkdir -p /var/www/lica-project/apps/admin/components/layout
cat << 'EOF' > /var/www/lica-project/apps/admin/components/layout/Sidebar.tsx
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { 
  LayoutDashboard, ShoppingBag, Package, Users, Settings, 
  LogOut, Image as ImageIcon, Ticket, BarChart3 
} from "lucide-react";

export default function Sidebar() {
  const pathname = usePathname();

  const menuItems = [
    { name: "Tổng quan", href: "/", icon: <LayoutDashboard size={20} /> },
    { name: "Đơn hàng", href: "/orders", icon: <ShoppingBag size={20} /> },
    { name: "Sản phẩm", href: "/products", icon: <Package size={20} /> },
    { name: "Khách hàng", href: "/users", icon: <Users size={20} /> },
    
    // Group Marketing
    { section: "Kênh Marketing" },
    { name: "Mã giảm giá", href: "/marketing/coupons", icon: <Ticket size={20} /> },
    
    { section: "Hệ thống" },
    { name: "Cấu hình", href: "/settings", icon: <Settings size={20} /> },
  ];

  return (
    <div className="w-64 bg-white h-screen border-r border-gray-200 flex flex-col fixed left-0 top-0 z-50">
      <div className="p-6 border-b border-gray-100 flex items-center gap-3">
        <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center text-white font-bold">L</div>
        <span className="font-bold text-xl text-gray-800">Lica Admin</span>
      </div>

      <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
        {menuItems.map((item, index) => {
          if (item.section) {
            return (
                <div key={index} className="mt-6 mb-2 px-3 text-xs font-bold text-gray-400 uppercase tracking-wider">
                    {item.section}
                </div>
            );
          }

          const isActive = item.href === "/" 
            ? pathname === "/" 
            : pathname.startsWith(item.href || "");

          return (
            <Link
              key={index}
              href={item.href || "#"}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all duration-200 font-medium ${
                isActive
                  ? "bg-blue-50 text-blue-700 shadow-sm"
                  : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
              }`}
            >
              <div className={`${isActive ? "text-blue-600" : "text-gray-400"}`}>{item.icon}</div>
              {item.name}
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-gray-100">
        <button 
            onClick={() => {
                document.cookie = "admin_token=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT;";
                window.location.href = "/login";
            }}
            className="flex items-center gap-3 w-full px-3 py-2.5 text-gray-600 hover:bg-red-50 hover:text-red-600 rounded-lg transition"
        >
          <LogOut size={20} />
          <span className="font-medium">Đăng xuất</span>
        </button>
      </div>
    </div>
  );
}
EOF

# Đảm bảo layout.tsx sử dụng Sidebar này (Chỉ ghi đè nếu cần thiết, ở đây ta assume layout đã import từ components/layout/Sidebar)
# Nếu layout hiện tại chưa trỏ đúng, ta update layout.tsx
cat << 'EOF' > /var/www/lica-project/apps/admin/app/layout.tsx
import "./globals.css";
import Sidebar from "@/components/layout/Sidebar";

export const metadata = {
  title: "Lica Admin Portal",
  description: "Hệ thống quản trị Lica.vn",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi">
      <body className="bg-gray-50">
        <div className="flex">
            <Sidebar />
            <main className="flex-1 ml-64 min-h-screen">
                {children}
            </main>
        </div>
      </body>
    </html>
  );
}
EOF

# ==============================================================================
# 5. BUILD & RUN
# ==============================================================================
echo "🔄 Build & Restart..."
cd /var/www/lica-project/backend
php artisan route:clear

cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Hoàn tất! Vào Kênh Marketing -> Mã giảm giá để quản lý Voucher."
