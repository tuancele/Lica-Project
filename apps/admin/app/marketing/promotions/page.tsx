'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import axios from 'axios';
import { Plus, Trash2, Calendar, Tag } from 'lucide-react';
import { format } from 'date-fns';

export default function PromotionListPage() {
  const [promotions, setPromotions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  // Helper tạo URL chuẩn
  const getAPI = (path: string) => {
      const baseURL = process.env.NEXT_PUBLIC_API_URL?.endsWith('/api/v1') 
            ? process.env.NEXT_PUBLIC_API_URL 
            : `${process.env.NEXT_PUBLIC_API_URL}/api/v1`;
      return `${baseURL}${path}`;
  };

  useEffect(() => {
    fetchPromotions();
  }, []);

  const fetchPromotions = async () => {
    try {
      // Fix: Dùng getAPI để đảm bảo có /api/v1
      const res = await axios.get(getAPI('/marketing/promotions'));
      setPromotions(res.data.data.data || []);
    } catch (error) {
      console.error("Lỗi tải danh sách:", error);
    } finally {
      setLoading(false);
    }
  };

  const deletePromotion = async (id: number) => {
    if (!confirm('Bạn có chắc muốn xóa chương trình này?')) return;
    try {
        await axios.delete(getAPI(`/marketing/promotions/${id}`));
        fetchPromotions();
    } catch (error) {
        alert('Xóa thất bại');
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold text-gray-800">Chương trình khuyến mãi</h1>
        <Link href="/marketing/promotions/create" className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700">
          <Plus className="w-4 h-4" /> Tạo chương trình mới
        </Link>
      </div>

      <div className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden">
        <table className="w-full text-left text-sm">
          <thead className="bg-gray-50 text-gray-600 uppercase text-xs">
            <tr>
              <th className="px-6 py-3">Tên chương trình</th>
              <th className="px-6 py-3">Thời gian</th>
              <th className="px-6 py-3 text-center">Sản phẩm</th>
              <th className="px-6 py-3 text-center">Trạng thái</th>
              <th className="px-6 py-3 text-right">Hành động</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
                <tr><td colSpan={5} className="px-6 py-8 text-center text-gray-500">Đang tải...</td></tr>
            ) : promotions.length === 0 ? (
                <tr><td colSpan={5} className="px-6 py-8 text-center text-gray-500">Chưa có chương trình nào.</td></tr>
            ) : (
                promotions.map((item) => {
                    const now = new Date();
                    const start = new Date(item.start_at);
                    const end = new Date(item.end_at);
                    let status = <span className="px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-600">Sắp diễn ra</span>;
                    
                    if (now >= start && now <= end) {
                        status = <span className="px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-700 animate-pulse">Đang diễn ra</span>;
                    } else if (now > end) {
                        status = <span className="px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-600">Đã kết thúc</span>;
                    }

                    return (
                        <tr key={item.id} className="hover:bg-gray-50">
                            <td className="px-6 py-4 font-medium text-gray-800">
                                <Link href={`/marketing/promotions/${item.id}`} className="hover:text-blue-600">
                                    {item.name}
                                </Link>
                            </td>
                            <td className="px-6 py-4 text-gray-500">
                                <div className="flex items-center gap-1 text-xs">
                                    <Calendar className="w-3 h-3" />
                                    {format(start, 'dd/MM/yyyy HH:mm')}
                                </div>
                                <div className="flex items-center gap-1 text-xs mt-1">
                                    <span className="ml-4 text-gray-400">đến</span>
                                    {format(end, 'dd/MM/yyyy HH:mm')}
                                </div>
                            </td>
                            <td className="px-6 py-4 text-center">
                                <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                                    {item.items_count} SP
                                </span>
                            </td>
                            <td className="px-6 py-4 text-center">{status}</td>
                            <td className="px-6 py-4 text-right">
                                <div className="flex justify-end gap-2">
                                    <button onClick={() => deletePromotion(item.id)} className="p-2 hover:bg-red-50 text-red-500 rounded">
                                        <Trash2 className="w-4 h-4" />
                                    </button>
                                </div>
                            </td>
                        </tr>
                    );
                })
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
