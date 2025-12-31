#!/bin/bash

echo "🛠️ Đang sửa lỗi cú pháp (Syntax Error) do ký tự lạ..."

# ==============================================================================
# 1. SỬA FILE DANH SÁCH ĐƠN HÀNG (apps/admin/app/orders/page.tsx)
# ==============================================================================
cat << 'EOF' > /var/www/lica-project/apps/admin/app/orders/page.tsx
"use client";

import { useState, useEffect, useCallback, Suspense } from "react";
import axios from "axios";
import { useSearchParams, useRouter, usePathname } from "next/navigation";
import Link from "next/link";
import { 
  Search, Eye, Truck, CheckCircle, XCircle, AlertCircle, Package, RefreshCcw, Loader2, ImageOff 
} from "lucide-react";
import { Order, OrderStatus } from "@/types/order";

const STATUS_MAP: Record<OrderStatus, { label: string; color: string; icon?: any }> = {
  all: { label: "Tất cả", color: "text-gray-600" },
  pending: { label: "Chờ xác nhận", color: "text-orange-600", icon: AlertCircle },
  processing: { label: "Chờ lấy hàng", color: "text-blue-600", icon: Package },
  shipping: { label: "Đang giao", color: "text-purple-600", icon: Truck },
  completed: { label: "Đã giao", color: "text-green-600", icon: CheckCircle },
  cancelled: { label: "Đã hủy", color: "text-red-600", icon: XCircle },
  returned: { label: "Trả hàng/Hoàn tiền", color: "text-red-500", icon: RefreshCcw },
};

function OrderListContent() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const [orders, setOrders] = useState<Order[]>([]);
  const [counts, setCounts] = useState<Record<string, number>>({});
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState<number | null>(null);

  const currentTab = (searchParams.get("status") as OrderStatus) || "all";
  const searchTerm = searchParams.get("q") || "";
  const [searchInput, setSearchInput] = useState(searchTerm);

  const fetchOrders = useCallback(async () => {
    try {
      setLoading(true);
      const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/order`, {
        params: { status: currentTab, q: searchTerm, page: searchParams.get("page") || 1 }
      });
      setOrders(res.data.data.data || []);
      setCounts(res.data.counts || {});
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [currentTab, searchTerm, searchParams]);

  useEffect(() => { fetchOrders(); }, [fetchOrders]);

  const handleTabChange = (status: OrderStatus) => {
    const params = new URLSearchParams(searchParams.toString());
    params.set("status", status);
    params.set("page", "1");
    router.push(`${pathname}?${params.toString()}`);
  };

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    const params = new URLSearchParams(searchParams.toString());
    if (searchInput) params.set("q", searchInput); else params.delete("q");
    router.push(`${pathname}?${params.toString()}`);
  };

  const updateStatus = async (id: number | string, newStatus: OrderStatus) => {
    if (!confirm(`Bạn chắc chắn muốn chuyển trạng thái sang "${STATUS_MAP[newStatus].label}"?`)) return;
    setUpdating(Number(id));
    try {
      await axios.put(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/${id}/status`, { status: newStatus });
      fetchOrders();
    } catch (err) {
      alert("Lỗi cập nhật trạng thái");
    } finally {
      setUpdating(null);
    }
  };

  return (
    <div className="p-6 max-w-7xl mx-auto bg-gray-50 min-h-screen">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Quản Lý Đơn Hàng</h1>
      </div>

      <div className="bg-white rounded-t-lg border-b shadow-sm flex overflow-x-auto no-scrollbar">
        {Object.keys(STATUS_MAP).map((key) => {
          const status = key as OrderStatus;
          const isActive = currentTab === status;
          const count = status === 'all' ? 0 : (counts[status] || 0);
          
          return (
            <button
              key={status}
              onClick={() => handleTabChange(status)}
              className={`flex items-center gap-2 px-6 py-4 text-sm font-medium whitespace-nowrap transition border-b-2 hover:text-blue-600 ${
                isActive ? "border-blue-600 text-blue-600" : "border-transparent text-gray-500 hover:bg-gray-50"
              }`}
            >
              {STATUS_MAP[status].label}
              {count > 0 && <span className="bg-gray-100 text-gray-600 text-xs py-0.5 px-2 rounded-full">{count}</span>}
            </button>
          );
        })}
      </div>

      <div className="bg-white p-4 shadow-sm mb-4">
        <form onSubmit={handleSearch} className="flex gap-3 max-w-lg">
          <div className="relative flex-1">
            <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
            <input 
              type="text" 
              placeholder="Tìm theo Mã đơn hàng, Tên khách, SĐT..." 
              className="w-full pl-10 pr-4 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 outline-none"
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
            />
          </div>
          <button type="submit" className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">Tìm</button>
        </form>
      </div>

      <div className="space-y-4">
        {loading ? (
          <div className="text-center p-10"><Loader2 className="animate-spin inline text-blue-600"/> Đang tải...</div>
        ) : orders.length > 0 ? (
          orders.map((order) => (
            <div key={order.id} className="bg-white rounded-lg shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition">
              <div className="bg-gray-50 px-4 py-3 border-b flex justify-between items-center text-sm">
                <div className="flex gap-4">
                  <Link href={`/orders/${order.code}`} className="font-bold text-gray-800 hover:text-blue-600 flex items-center gap-2 group">
                    {order.customer_name} 
                    <span className="text-gray-500 font-mono group-hover:text-blue-500">#{order.code}</span>
                  </Link>
                </div>
                <div className={`flex items-center gap-1 font-medium uppercase ${STATUS_MAP[order.status as OrderStatus]?.color || 'text-gray-600'}`}>
                  {STATUS_MAP[order.status as OrderStatus]?.label}
                </div>
              </div>

              <div className="p-4 cursor-pointer" onClick={() => router.push(`/orders/${order.code}`)}>
                {order.items.map((item) => (
                  <div key={item.id} className="flex gap-4 mb-3 last:mb-0">
                    <div className="w-16 h-16 bg-gray-100 rounded border flex-shrink-0 flex items-center justify-center overflow-hidden">
                      {item.product?.thumbnail ? (
                        <img 
                          src={item.product.thumbnail} 
                          alt={item.product_name} 
                          className="w-full h-full object-cover"
                          onError={(e) => {
                            e.currentTarget.style.display = 'none';
                            e.currentTarget.parentElement?.classList.add('bg-gray-200');
                          }} 
                        />
                      ) : (
                        <ImageOff size={20} className="text-gray-400" />
                      )}
                    </div>
                    <div className="flex-1">
                      <div className="text-gray-800 font-medium line-clamp-2">{item.product_name}</div>
                      <div className="text-gray-500 text-sm">Phân loại: Mặc định</div>
                      <div className="text-sm mt-1">x{item.quantity}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-blue-600 font-medium">₫{new Intl.NumberFormat('vi-VN').format(item.price)}</div>
                    </div>
                  </div>
                ))}
              </div>

              <div className="px-4 py-3 border-t bg-gray-50/50 flex flex-col md:flex-row justify-between items-center gap-4">
                <div className="text-sm text-gray-600">
                  Tổng đơn hàng: <span className="text-xl font-bold text-red-600">₫{new Intl.NumberFormat('vi-VN').format(order.total_amount)}</span>
                </div>
                
                <div className="flex gap-2">
                  {order.status === 'pending' && (
                    <>
                      <button onClick={() => updateStatus(order.id, 'cancelled')} className="px-4 py-2 border border-gray-300 rounded text-gray-700 hover:bg-gray-100">Hủy đơn</button>
                      <button onClick={() => updateStatus(order.id, 'processing')} className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700">Chuẩn bị hàng</button>
                    </>
                  )}

                  {order.status === 'processing' && (
                    <button onClick={() => updateStatus(order.id, 'shipping')} className="px-4 py-2 bg-purple-600 text-white rounded hover:bg-purple-700 flex items-center gap-2">
                      <Truck size={16}/> Giao cho ĐVVC
                    </button>
                  )}

                  {order.status === 'shipping' && (
                    <>
                      <button onClick={() => updateStatus(order.id, 'returned')} className="px-4 py-2 border border-red-200 text-red-600 rounded hover:bg-red-50">Khách trả hàng</button>
                      <button onClick={() => updateStatus(order.id, 'completed')} className="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700">Đã giao hàng</button>
                    </>
                  )}

                  <Link href={`/orders/${order.code}`} className="px-3 py-2 text-gray-500 hover:text-blue-600 rounded hover:bg-blue-50" title="Xem chi tiết">
                    <Eye size={20}/>
                  </Link>
                </div>
              </div>
            </div>
          ))
        ) : (
          <div className="flex flex-col items-center justify-center p-12 bg-white rounded-lg shadow-sm border border-dashed border-gray-300 text-gray-500">
            <Package size={48} className="mb-3 text-gray-300" />
            <p>Không tìm thấy đơn hàng nào.</p>
          </div>
        )}
      </div>
    </div>
  );
}

export default function OrderPage() {
  return (
    <Suspense fallback={<div className="p-10 text-center">Đang tải...</div>}>
      <OrderListContent />
    </Suspense>
  );
}
EOF

# ==============================================================================
# 2. SỬA FILE CHI TIẾT ĐƠN HÀNG (apps/admin/app/orders/[id]/page.tsx)
# ==============================================================================
cat << 'EOF' > /var/www/lica-project/apps/admin/app/orders/[id]/page.tsx
"use client";

import { useEffect, useState, use } from "react";
import axios from "axios";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { 
  ArrowLeft, Printer, Truck, User, MapPin, CreditCard, 
  Package, Calendar, Phone, Mail, CheckCircle, XCircle, AlertCircle, ImageOff 
} from "lucide-react";
import { Order, OrderStatus } from "@/types/order";

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

  const handleUpdateStatus = async (newStatus: OrderStatus) => {
    if (!confirm(`Xác nhận chuyển trạng thái đơn hàng sang: ${STATUS_MAP[newStatus].label}?`)) return;
    setUpdating(true);
    try {
      await axios.put(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/${id}/status`, { status: newStatus });
      await fetchOrderDetail();
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
          <div className="lg:col-span-2 space-y-6">
            
            <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
              <div className="px-6 py-4 border-b border-gray-100 font-bold text-gray-800 flex items-center gap-2">
                <Package size={20} className="text-blue-600"/> Danh sách sản phẩm
              </div>
              <div className="divide-y divide-gray-100">
                {order.items.map((item) => (
                  <div key={item.id} className="p-4 flex gap-4 items-center hover:bg-gray-50 transition">
                    <div className="w-16 h-16 border rounded-lg overflow-hidden flex-shrink-0 bg-gray-100 flex items-center justify-center">
                      {item.product?.thumbnail ? (
                        <img 
                          src={item.product.thumbnail} 
                          alt="" 
                          className="w-full h-full object-cover" 
                          onError={(e) => {
                            e.currentTarget.style.display = 'none';
                            e.currentTarget.parentElement?.classList.add('bg-gray-200');
                          }}
                        />
                      ) : (
                        <ImageOff size={24} className="text-gray-400"/>
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

          <div className="space-y-6">
            
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

# ==============================================================================
# 3. BUILD & RESTART
# ==============================================================================
echo "🔄 Build lại Admin App..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Đã sửa xong lỗi cú pháp! Hãy thử lại trang đơn hàng."
