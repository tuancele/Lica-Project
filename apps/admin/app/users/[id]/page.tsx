"use client";

import { useEffect, useState, use } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { 
  ArrowLeft, User, Mail, Phone, MapPin, Calendar, 
  ShoppingBag, DollarSign, CheckCircle, XCircle, AlertCircle, Package 
} from "lucide-react";

export default function UserDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const [user, setUser] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUser = async () => {
      try {
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/users/${id}`);
        setUser(res.data.data);
      } catch (err) {
        alert("Không tìm thấy thành viên");
        router.push("/users");
      } finally {
        setLoading(false);
      }
    };
    fetchUser();
  }, [id, router]);

  if (loading) return <div className="min-h-screen flex justify-center items-center text-gray-500">Đang tải hồ sơ...</div>;
  if (!user) return null;

  return (
    <div className="min-h-screen bg-gray-50 p-6 font-sans">
      <div className="max-w-6xl mx-auto">
        <Link href="/users" className="inline-flex items-center gap-2 text-gray-500 hover:text-blue-600 mb-6 transition">
            <ArrowLeft size={18}/> Quay lại danh sách
        </Link>

        {/* HEADER PROFILE */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6 flex flex-col md:flex-row items-center gap-6">
            <div className="w-24 h-24 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white text-3xl font-bold uppercase shadow-lg">
                {user.name ? user.name[0] : <User size={40}/>}
            </div>
            <div className="flex-1 text-center md:text-left">
                <h1 className="text-2xl font-bold text-gray-900">{user.name}</h1>
                <div className="flex flex-wrap justify-center md:justify-start gap-4 text-gray-500 mt-2 text-sm">
                    <span className="flex items-center gap-1">@{user.username}</span>
                    {user.email && <span className="flex items-center gap-1"><Mail size={14}/> {user.email}</span>}
                    {user.phone && <span className="flex items-center gap-1"><Phone size={14}/> {user.phone}</span>}
                    <span className="flex items-center gap-1"><Calendar size={14}/> Tham gia: {new Date(user.created_at).toLocaleDateString('vi-VN')}</span>
                </div>
            </div>
            <div className="flex flex-col items-end gap-2">
                <span className={`px-4 py-1.5 rounded-full text-sm font-bold uppercase tracking-wide ${
                    user.membership_tier === 'diamond' ? 'bg-purple-100 text-purple-700' : 
                    user.membership_tier === 'gold' ? 'bg-yellow-100 text-yellow-700' : 'bg-gray-100 text-gray-600'
                }`}>
                    {user.membership_tier || 'Member'}
                </span>
                <span className="text-xs text-gray-400">ID: {user.id}</span>
            </div>
        </div>

        {/* ANALYTICS CARDS */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
            <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-200">
                <div className="text-gray-500 text-xs font-bold uppercase mb-2 flex items-center gap-2"><DollarSign size={14}/> Tổng chi tiêu</div>
                <div className="text-2xl font-bold text-blue-600">{new Intl.NumberFormat('vi-VN').format(user.analytics?.total_spent || 0)}đ</div>
            </div>
            <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-200">
                <div className="text-gray-500 text-xs font-bold uppercase mb-2 flex items-center gap-2"><ShoppingBag size={14}/> Tổng đơn hàng</div>
                <div className="text-2xl font-bold text-gray-800">{user.analytics?.total_orders || 0}</div>
            </div>
            <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-200">
                <div className="text-gray-500 text-xs font-bold uppercase mb-2 flex items-center gap-2"><CheckCircle size={14}/> Thành công</div>
                <div className="text-2xl font-bold text-green-600">{user.analytics?.completed_orders || 0}</div>
            </div>
            <div className="bg-white p-5 rounded-xl shadow-sm border border-gray-200">
                <div className="text-gray-500 text-xs font-bold uppercase mb-2 flex items-center gap-2"><XCircle size={14}/> Hủy / Trả</div>
                <div className="text-2xl font-bold text-red-600">{user.analytics?.cancelled_orders || 0}</div>
            </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {/* LEFT COLUMN: INFO & ADDRESSES */}
            <div className="space-y-6">
                <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-5">
                    <h3 className="font-bold text-gray-800 mb-4 flex items-center gap-2"><MapPin size={18}/> Sổ địa chỉ</h3>
                    <div className="space-y-3">
                        {user.addresses && user.addresses.length > 0 ? (
                            user.addresses.map((addr: any) => (
                                <div key={addr.id} className={`p-3 border rounded-lg text-sm relative ${addr.is_default ? 'bg-blue-50 border-blue-200' : 'bg-gray-50 border-gray-100'}`}>
                                    {addr.is_default && <span className="absolute top-2 right-2 text-[10px] bg-blue-600 text-white px-2 py-0.5 rounded-full">Mặc định</span>}
                                    <div className="font-bold text-gray-900">{addr.name} - {addr.phone}</div>
                                    <div className="text-gray-600 mt-1">{addr.address}</div>
                                </div>
                            ))
                        ) : (
                            <p className="text-gray-400 text-sm italic">Chưa lưu địa chỉ nào.</p>
                        )}
                    </div>
                </div>
            </div>

            {/* RIGHT COLUMN: ORDER HISTORY */}
            <div className="lg:col-span-2">
                <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
                    <div className="p-5 border-b border-gray-100 font-bold text-gray-800 flex items-center gap-2">
                        <Package size={18}/> Lịch sử đơn hàng
                    </div>
                    <div className="overflow-x-auto">
                        <table className="w-full text-left text-sm">
                            <thead className="bg-gray-50 text-gray-500 text-xs uppercase">
                                <tr>
                                    <th className="px-5 py-3">Mã đơn</th>
                                    <th className="px-5 py-3">Ngày đặt</th>
                                    <th className="px-5 py-3">Trạng thái</th>
                                    <th className="px-5 py-3 text-right">Tổng tiền</th>
                                    <th className="px-5 py-3"></th>
                                </tr>
                            </thead>
                            <tbody className="divide-y divide-gray-100">
                                {user.orders && user.orders.length > 0 ? (
                                    user.orders.map((order: any) => (
                                        <tr key={order.id} className="hover:bg-gray-50 transition">
                                            <td className="px-5 py-3 font-medium text-blue-600">#{order.code}</td>
                                            <td className="px-5 py-3 text-gray-500">{new Date(order.created_at).toLocaleDateString('vi-VN')}</td>
                                            <td className="px-5 py-3">
                                                <span className={`px-2 py-1 rounded text-xs font-bold uppercase ${
                                                    order.status === 'completed' ? 'bg-green-100 text-green-700' :
                                                    order.status === 'cancelled' ? 'bg-red-100 text-red-700' :
                                                    'bg-orange-100 text-orange-700'
                                                }`}>
                                                    {order.status}
                                                </span>
                                            </td>
                                            <td className="px-5 py-3 text-right font-bold text-gray-800">
                                                {new Intl.NumberFormat('vi-VN').format(order.total_amount)}đ
                                            </td>
                                            <td className="px-5 py-3 text-right">
                                                <Link href={`/orders/${order.code}`} className="text-blue-600 hover:underline text-xs">Chi tiết</Link>
                                            </td>
                                        </tr>
                                    ))
                                ) : (
                                    <tr>
                                        <td colSpan={5} className="p-8 text-center text-gray-400">Chưa có đơn hàng nào.</td>
                                    </tr>
                                )}
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>
      </div>
    </div>
  );
}
