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
      
      {/* Fix: Map Product[] -> number[] */}
      {showProductModal && (
        <ProductSelector 
            selectedIds={form.product_ids} 
            onChange={(products) => setForm({...form, product_ids: products.map((p: any) => p.id)})} 
            onClose={() => setShowProductModal(false)} 
        />
      )}
    </div>
  );
}
