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
