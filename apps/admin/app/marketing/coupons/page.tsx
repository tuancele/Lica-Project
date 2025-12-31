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
