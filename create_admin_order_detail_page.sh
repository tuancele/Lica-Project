#!/bin/bash

echo "🚀 Đang tạo trang Chi tiết đơn hàng (Admin)..."

mkdir -p /var/www/lica-project/apps/admin/app/orders/[id]

# ==============================================================================
# TẠO TRANG ADMIN ORDER DETAIL
# ==============================================================================
cat << 'EOF' > /var/www/lica-project/apps/admin/app/orders/[id]/page.tsx
"use client";

import { useEffect, useState, use } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { 
  ArrowLeft, User, Phone, MapPin, Calendar, CreditCard, 
  Package, Truck, CheckCircle, XCircle, AlertCircle, Save 
} from "lucide-react";

export default function OrderDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const [order, setOrder] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);
  const [status, setStatus] = useState("");

  useEffect(() => {
    const fetchOrder = async () => {
      try {
        // QUAN TRỌNG: Dùng 'orders' số nhiều (API quản lý)
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/orders/${id}`);
        setOrder(res.data.data);
        setStatus(res.data.data.status);
      } catch (err) {
        console.error(err);
        alert("Không tìm thấy đơn hàng hoặc lỗi kết nối.");
        router.push("/orders");
      } finally {
        setLoading(false);
      }
    };
    fetchOrder();
  }, [id, router]);

  const handleUpdateStatus = async () => {
    setUpdating(true);
    try {
        await axios.put(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/orders/${order.id}/status`, { status });
        alert("Cập nhật trạng thái thành công!");
        // Refresh data local
        setOrder({ ...order, status });
    } catch (err) {
        alert("Lỗi cập nhật trạng thái.");
    } finally {
        setUpdating(false);
    }
  };

  const getStatusColor = (s: string) => {
    switch(s) {
        case 'pending': return 'bg-yellow-100 text-yellow-700';
        case 'processing': return 'bg-blue-100 text-blue-700';
        case 'shipping': return 'bg-purple-100 text-purple-700';
        case 'completed': return 'bg-green-100 text-green-700';
        case 'cancelled': return 'bg-red-100 text-red-700';
        default: return 'bg-gray-100 text-gray-600';
    }
  };

  if (loading) return <div className="min-h-screen flex justify-center items-center text-gray-500">Đang tải dữ liệu đơn hàng...</div>;
  if (!order) return null;

  return (
    <div className="p-6 bg-gray-50 min-h-screen font-sans pb-20">
      <div className="max-w-5xl mx-auto">
        {/* Navigation */}
        <div className="flex items-center justify-between mb-6">
            <Link href="/orders" className="inline-flex items-center gap-2 text-gray-500 hover:text-blue-600 transition">
                <ArrowLeft size={18}/> Quay lại danh sách
            </Link>
            <div className="text-sm text-gray-400">ID Hệ thống: {order.id}</div>
        </div>

        {/* Header Info */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6 mb-6">
            <div className="flex flex-col md:flex-row justify-between md:items-center gap-4 border-b border-gray-100 pb-6 mb-6">
                <div>
                    <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
                        Đơn hàng #{order.code}
                        <span className={`text-xs px-3 py-1 rounded-full uppercase ${getStatusColor(order.status)}`}>{order.status}</span>
                    </h1>
                    <div className="text-gray-500 text-sm mt-1 flex gap-4">
                        <span className="flex items-center gap-1"><Calendar size={14}/> {new Date(order.created_at).toLocaleString('vi-VN')}</span>
                        <span className="flex items-center gap-1"><CreditCard size={14}/> {order.payment_method === 'cod' ? 'Thanh toán khi nhận hàng (COD)' : 'Chuyển khoản'}</span>
                    </div>
                </div>
                
                {/* Status Actions */}
                <div className="flex items-center gap-2 bg-gray-50 p-2 rounded-lg border border-gray-200">
                    <span className="text-sm font-medium text-gray-600 pl-2">Trạng thái:</span>
                    <select 
                        className="bg-white border border-gray-300 text-sm rounded px-3 py-1.5 focus:ring-2 focus:ring-blue-500 outline-none"
                        value={status}
                        onChange={(e) => setStatus(e.target.value)}
                    >
                        <option value="pending">Chờ xử lý</option>
                        <option value="processing">Đang chuẩn bị</option>
                        <option value="shipping">Đang giao hàng</option>
                        <option value="completed">Hoàn thành</option>
                        <option value="cancelled">Đã hủy</option>
                    </select>
                    <button 
                        onClick={handleUpdateStatus} 
                        disabled={updating || status === order.status}
                        className="bg-blue-600 text-white px-4 py-1.5 rounded text-sm font-bold hover:bg-blue-700 disabled:opacity-50 flex items-center gap-1 transition"
                    >
                        {updating ? 'Lưu...' : <><Save size={14}/> Lưu</>}
                    </button>
                </div>
            </div>

            {/* Customer & Shipping */}
            <div className="grid md:grid-cols-2 gap-8">
                <div>
                    <h3 className="font-bold text-gray-800 uppercase text-xs mb-3 flex items-center gap-2"><User size={16}/> Thông tin khách hàng</h3>
                    <div className="space-y-2 text-sm text-gray-600">
                        <div className="flex justify-between border-b border-dashed pb-1"><span>Họ tên:</span> <span className="font-medium text-gray-900">{order.customer_name}</span></div>
                        <div className="flex justify-between border-b border-dashed pb-1"><span>Số điện thoại:</span> <span className="font-medium text-gray-900">{order.customer_phone}</span></div>
                        <div className="flex justify-between border-b border-dashed pb-1"><span>Email:</span> <span>{order.customer_email || 'Chưa cung cấp'}</span></div>
                        {order.user_id && <div className="flex justify-between border-b border-dashed pb-1"><span>Tài khoản:</span> <Link href={`/users/${order.user_id}`} className="text-blue-600 hover:underline">Xem hồ sơ</Link></div>}
                    </div>
                </div>
                <div>
                    <h3 className="font-bold text-gray-800 uppercase text-xs mb-3 flex items-center gap-2"><MapPin size={16}/> Địa chỉ giao hàng</h3>
                    <div className="bg-gray-50 p-3 rounded text-sm text-gray-700 leading-relaxed border border-gray-200">
                        {order.shipping_address}
                    </div>
                    {order.note && (
                        <div className="mt-3">
                            <span className="text-xs font-bold text-orange-600 uppercase">Ghi chú:</span>
                            <p className="text-sm text-gray-600 italic bg-orange-50 p-2 rounded border border-orange-100 mt-1">{order.note}</p>
                        </div>
                    )}
                </div>
            </div>
        </div>

        {/* Order Items */}
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
            <div className="bg-gray-50 px-6 py-4 border-b border-gray-200 font-bold text-gray-700 flex items-center gap-2">
                <Package size={18}/> Danh sách sản phẩm
            </div>
            <table className="w-full text-left text-sm">
                <thead className="bg-white text-gray-500 border-b">
                    <tr>
                        <th className="px-6 py-3 font-medium">Sản phẩm</th>
                        <th className="px-6 py-3 font-medium text-center">Đơn giá</th>
                        <th className="px-6 py-3 font-medium text-center">Số lượng</th>
                        <th className="px-6 py-3 font-medium text-right">Thành tiền</th>
                    </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                    {order.items?.map((item: any) => (
                        <tr key={item.id} className="hover:bg-gray-50">
                            <td className="px-6 py-4">
                                <div className="font-medium text-gray-900">{item.product_name}</div>
                                <div className="text-xs text-gray-500">SKU: {item.sku}</div>
                            </td>
                            <td className="px-6 py-4 text-center">{new Intl.NumberFormat('vi-VN').format(item.price)}đ</td>
                            <td className="px-6 py-4 text-center">x{item.quantity}</td>
                            <td className="px-6 py-4 text-right font-medium">{new Intl.NumberFormat('vi-VN').format(item.total)}đ</td>
                        </tr>
                    ))}
                </tbody>
                <tfoot className="bg-gray-50">
                    <tr>
                        <td colSpan={3} className="px-6 py-3 text-right text-gray-600">Tạm tính:</td>
                        <td className="px-6 py-3 text-right font-medium">{new Intl.NumberFormat('vi-VN').format(order.total_amount + (Number(order.discount_amount) || 0))}đ</td>
                    </tr>
                    {Number(order.discount_amount) > 0 && (
                        <tr>
                            <td colSpan={3} className="px-6 py-2 text-right text-green-600">
                                Voucher {order.coupon_code ? `(${order.coupon_code})` : ''}:
                            </td>
                            <td className="px-6 py-2 text-right font-medium text-green-600">
                                -{new Intl.NumberFormat('vi-VN').format(order.discount_amount)}đ
                            </td>
                        </tr>
                    )}
                    <tr>
                        <td colSpan={3} className="px-6 py-4 text-right font-bold text-lg text-gray-800">Tổng cộng:</td>
                        <td className="px-6 py-4 text-right font-bold text-lg text-red-600">{new Intl.NumberFormat('vi-VN').format(order.total_amount)}đ</td>
                    </tr>
                </tfoot>
            </table>
        </div>
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# BUILD LẠI
# ==============================================================================
echo "🔄 Build lại Admin App..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Đã tạo trang Chi tiết đơn hàng! Hãy thử bấm lại vào mã đơn."
