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
