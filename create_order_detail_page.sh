#!/bin/bash

echo "🚀 Đang tạo trang Chi tiết đơn hàng (Order Detail)..."

# Tạo thư mục nếu chưa có (dự phòng)
mkdir -p /var/www/lica-project/apps/admin/app/orders/[id]

# Ghi nội dung file
cat << 'EOF' > /var/www/lica-project/apps/admin/app/orders/[id]/page.tsx
"use client";

import { useEffect, useState, use } from "react";
import axios from "axios";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { 
  ArrowLeft, Printer, Truck, User, MapPin, CreditCard, 
  Package, Calendar, Phone, Mail, AlertCircle, CheckCircle, XCircle 
} from "lucide-react";
import { Order, OrderStatus } from "@/types/order";

// Mapping trạng thái (Tái sử dụng logic hiển thị)
const STATUS_MAP: Record<string, { label: string; color: string; bg: string }> = {
  pending: { label: "Chờ xác nhận", color: "text-orange-700", bg: "bg-orange-50" },
  processing: { label: "Chờ lấy hàng", color: "text-blue-700", bg: "bg-blue-50" },
  shipping: { label: "Đang giao", color: "text-purple-700", bg: "bg-purple-50" },
  completed: { label: "Đã giao hàng", color: "text-green-700", bg: "bg-green-50" },
  cancelled: { label: "Đã hủy", color: "text-red-700", bg: "bg-red-50" },
  returned: { label: "Trả hàng/Hoàn tiền", color: "text-red-800", bg: "bg-red-100" },
};

export default function OrderDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  
  const [order, setOrder] = useState<Order | null>(null);
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);

  // Fetch dữ liệu chi tiết đơn hàng
  const fetchOrderDetail = async () => {
    try {
      setLoading(true);
      const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/${id}`);
      setOrder(res.data.data);
    } catch (err) {
      console.error(err);
      alert("Không tìm thấy đơn hàng");
      router.push("/orders");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (id) fetchOrderDetail();
  }, [id]);

  // Hàm xử lý chuyển trạng thái
  const handleUpdateStatus = async (newStatus: OrderStatus) => {
    if (!confirm(`Xác nhận chuyển trạng thái đơn hàng sang: ${STATUS_MAP[newStatus].label}?`)) return;
    
    setUpdating(true);
    try {
      await axios.put(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/${id}/status`, { status: newStatus });
      await fetchOrderDetail(); // Reload lại dữ liệu mới nhất
    } catch (err) {
      alert("Lỗi cập nhật trạng thái");
    } finally {
      setUpdating(false);
    }
  };

  if (loading) return <div className="min-h-screen flex items-center justify-center text-gray-500">Đang tải thông tin đơn hàng...</div>;
  if (!order) return null;

  const statusInfo = STATUS_MAP[order.status] || { label: order.status, color: "text-gray-700", bg: "bg-gray-100" };

  return (
    <div className="min-h-screen bg-gray-50 p-6 font-sans">
      <div className="max-w-5xl mx-auto">
        {/* Header: Nút back & Title */}
        <div className="flex items-center justify-between mb-6">
          <div className="flex items-center gap-3">
            <Link href="/orders" className="p-2 bg-white border rounded-lg hover:bg-gray-100 text-gray-600 transition">
              <ArrowLeft size={20} />
            </Link>
            <div>
              <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
                Đơn hàng #{order.code}
                <span className={`px-3 py-1 rounded-full text-sm font-medium ${statusInfo.bg} ${statusInfo.color}`}>
                  {statusInfo.label}
                </span>
              </h1>
              <div className="text-sm text-gray-500 flex items-center gap-2 mt-1">
                <Calendar size={14} /> Ngày đặt: {new Date(order.created_at).toLocaleString('vi-VN')}
              </div>
            </div>
          </div>
          <button onClick={() => window.print()} className="flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 font-medium shadow-sm">
            <Printer size={18} /> In đơn hàng
          </button>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          {/* Cột trái: Danh sách sản phẩm & Thanh toán (Chiếm 2 phần) */}
          <div className="lg:col-span-2 space-y-6">
            
            {/* Card: Sản phẩm */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
              <div className="px-6 py-4 border-b border-gray-100 font-bold text-gray-800 flex items-center gap-2">
                <Package size={20} className="text-blue-600"/> Danh sách sản phẩm
              </div>
              <div className="divide-y divide-gray-100">
                {order.items.map((item) => (
                  <div key={item.id} className="p-4 flex gap-4 items-center hover:bg-gray-50 transition">
                    <div className="w-16 h-16 border rounded-lg overflow-hidden flex-shrink-0 bg-gray-100">
                      {item.product?.thumbnail ? (
                        <img src={item.product.thumbnail} alt="" className="w-full h-full object-cover" />
                      ) : (
                        <div className="w-full h-full flex items-center justify-center text-gray-400"><Package size={24}/></div>
                      )}
                    </div>
                    <div className="flex-1">
                      <div className="font-medium text-gray-900">{item.product_name}</div>
                      <div className="text-xs text-gray-500 mt-1 font-mono">SKU: {item.sku || "N/A"}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-sm font-medium text-gray-900">
                        {new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(item.price)}
                      </div>
                      <div className="text-xs text-gray-500">x{item.quantity}</div>
                    </div>
                    <div className="text-right w-24 font-bold text-blue-600">
                      {new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(item.total)}
                    </div>
                  </div>
                ))}
              </div>
              
              {/* Tổng tiền */}
              <div className="bg-gray-50 px-6 py-4 border-t border-gray-200">
                <div className="flex justify-between text-sm mb-2">
                  <span className="text-gray-600">Tạm tính:</span>
                  <span className="font-medium">{new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(order.total_amount)}</span>
                </div>
                <div className="flex justify-between text-sm mb-2">
                  <span className="text-gray-600">Phí vận chuyển:</span>
                  <span className="font-medium">0 ₫</span>
                </div>
                <div className="flex justify-between text-lg font-bold text-gray-900 mt-3 pt-3 border-t border-gray-200">
                  <span>Tổng thanh toán:</span>
                  <span className="text-red-600">{new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(order.total_amount)}</span>
                </div>
              </div>
            </div>

            {/* Card: Thanh toán */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <h3 className="font-bold text-gray-800 mb-4 flex items-center gap-2">
                <CreditCard size={20} className="text-green-600"/> Thanh toán
              </h3>
              <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg border border-gray-100">
                <span className="text-gray-600">Phương thức:</span>
                <span className="font-medium text-gray-900 uppercase">
                  {order.payment_method === 'cash_on_delivery' ? 'Thanh toán khi nhận hàng (COD)' : 'Chuyển khoản ngân hàng'}
                </span>
              </div>
            </div>
          </div>

          {/* Cột phải: Thông tin khách hàng & Hành động (Chiếm 1 phần) */}
          <div className="space-y-6">
            
            {/* Card: Hành động (Quan trọng nhất) */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <h3 className="font-bold text-gray-800 mb-4">Xử lý đơn hàng</h3>
              <div className="space-y-3">
                {order.status === 'pending' && (
                  <>
                    <button onClick={() => handleUpdateStatus('processing')} disabled={updating} className="w-full py-2.5 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 transition flex justify-center items-center gap-2">
                      <CheckCircle size={18}/> Xác nhận & Chuẩn bị
                    </button>
                    <button onClick={() => handleUpdateStatus('cancelled')} disabled={updating} className="w-full py-2.5 bg-white border border-red-300 text-red-600 rounded-lg font-medium hover:bg-red-50 transition flex justify-center items-center gap-2">
                      <XCircle size={18}/> Hủy đơn hàng
                    </button>
                  </>
                )}

                {order.status === 'processing' && (
                  <button onClick={() => handleUpdateStatus('shipping')} disabled={updating} className="w-full py-2.5 bg-purple-600 text-white rounded-lg font-medium hover:bg-purple-700 transition flex justify-center items-center gap-2">
                    <Truck size={18}/> Giao cho vận chuyển
                  </button>
                )}

                {order.status === 'shipping' && (
                  <>
                    <button onClick={() => handleUpdateStatus('completed')} disabled={updating} className="w-full py-2.5 bg-green-600 text-white rounded-lg font-medium hover:bg-green-700 transition flex justify-center items-center gap-2">
                      <CheckCircle size={18}/> Đã giao thành công
                    </button>
                    <button onClick={() => handleUpdateStatus('returned')} disabled={updating} className="w-full py-2.5 border border-orange-300 text-orange-600 rounded-lg font-medium hover:bg-orange-50 transition flex justify-center items-center gap-2">
                      <AlertCircle size={18}/> Khách trả hàng
                    </button>
                  </>
                )}

                {(order.status === 'completed' || order.status === 'cancelled' || order.status === 'returned') && (
                  <div className="text-center text-sm text-gray-500 py-2 italic bg-gray-50 rounded">
                    Đơn hàng đã hoàn tất quy trình.
                  </div>
                )}
              </div>
            </div>

            {/* Card: Thông tin khách hàng */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <h3 className="font-bold text-gray-800 mb-4 flex items-center gap-2">
                <User size={20} className="text-orange-600"/> Khách hàng
              </h3>
              <div className="space-y-4">
                <div className="flex items-start gap-3">
                  <User size={18} className="text-gray-400 mt-0.5" />
                  <div>
                    <div className="text-xs text-gray-500 uppercase font-semibold">Họ tên</div>
                    <div className="text-gray-900 font-medium">{order.customer_name}</div>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <Phone size={18} className="text-gray-400 mt-0.5" />
                  <div>
                    <div className="text-xs text-gray-500 uppercase font-semibold">Điện thoại</div>
                    <div className="text-gray-900 font-medium">{order.customer_phone}</div>
                  </div>
                </div>
                {order.customer_email && (
                  <div className="flex items-start gap-3">
                    <Mail size={18} className="text-gray-400 mt-0.5" />
                    <div>
                      <div className="text-xs text-gray-500 uppercase font-semibold">Email</div>
                      <div className="text-gray-900">{order.customer_email}</div>
                    </div>
                  </div>
                )}
              </div>
            </div>

            {/* Card: Địa chỉ giao hàng */}
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
              <h3 className="font-bold text-gray-800 mb-4 flex items-center gap-2">
                <MapPin size={20} className="text-red-600"/> Địa chỉ nhận hàng
              </h3>
              <p className="text-gray-700 leading-relaxed bg-gray-50 p-3 rounded-lg border border-gray-100">
                {order.shipping_address}
              </p>
            </div>

          </div>
        </div>
      </div>
    </div>
  );
}
EOF

echo "🔄 Đang build lại Admin App..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Đã tạo xong trang Chi tiết đơn hàng! Truy cập bằng cách bấm vào biểu tượng con mắt ở danh sách đơn."
