#!/bin/bash

echo "🚀 Đang nâng cấp giao diện Quản lý đơn hàng (Shopee Style)..."

# ==============================================================================
# CẬP NHẬT TRANG ORDERS (Giao diện Tab & Quick Actions)
# ==============================================================================
cat << 'EOF' > /var/www/lica-project/apps/admin/app/orders/page.tsx
"use client";

import { useState, useEffect, useCallback } from "react";
import axios from "axios";
import Link from "next/link";
import { 
  ShoppingBag, Eye, Search, Loader2, RefreshCw, 
  CheckCircle, Truck, PackageCheck, XCircle, AlertTriangle 
} from "lucide-react";

interface Order {
  id: number;
  code: string;
  customer_name: string;
  customer_phone?: string;
  total_amount: number;
  status: string;
  payment_status: string;
  created_at: string;
  items_count?: number;
}

export default function OrdersPage() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [processingId, setProcessingId] = useState<number | null>(null); // ID đang xử lý action
  const [pagination, setPagination] = useState<any>(null);
  
  // Filter State
  const [status, setStatus] = useState('all');
  const [search, setSearch] = useState('');

  // Danh sách Tab trạng thái
  const tabs = [
    { id: 'all', label: 'Tất cả' },
    { id: 'pending', label: 'Chờ xác nhận' },
    { id: 'processing', label: 'Chờ lấy hàng' },
    { id: 'shipping', label: 'Đang giao' },
    { id: 'completed', label: 'Hoàn thành' },
    { id: 'cancelled', label: 'Đã hủy' },
  ];

  // Fetch Data
  const fetchOrders = useCallback(async (page = 1) => {
    setLoading(true);
    try {
      const params = { 
        page, 
        q: search, 
        status: status !== 'all' ? status : undefined 
      };
      
      const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/orders`, { params });
      if (res.data && res.data.data && Array.isArray(res.data.data.data)) {
         setOrders(res.data.data.data);
         setPagination(res.data.data);
      } else {
         setOrders([]);
      }
    } catch (err) {
      console.error(err);
      setOrders([]);
    } finally {
      setLoading(false);
    }
  }, [status, search]);

  // Debounce search
  useEffect(() => {
    const timer = setTimeout(() => fetchOrders(), 500); 
    return () => clearTimeout(timer);
  }, [fetchOrders]);

  // Quick Action Handler
  const handleQuickAction = async (id: number, newStatus: string) => {
    if (!confirm(`Bạn chắc chắn muốn chuyển trạng thái sang "${getStatusLabel(newStatus)}"?`)) return;
    
    setProcessingId(id);
    try {
        await axios.put(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/orders/${id}/status`, { status: newStatus });
        // Cập nhật UI local ngay lập tức để cảm giác nhanh
        setOrders(prev => prev.map(o => o.id === id ? { ...o, status: newStatus } : o));
    } catch (err) {
        alert("Lỗi cập nhật trạng thái");
        fetchOrders(); // Reload nếu lỗi để đồng bộ lại
    } finally {
        setProcessingId(null);
    }
  };

  // Helper Labels
  const getStatusLabel = (s: string) => {
     const map: any = { pending: 'Chờ xác nhận', processing: 'Đang chuẩn bị', shipping: 'Đang giao', completed: 'Hoàn thành', cancelled: 'Đã hủy' };
     return map[s] || s;
  };

  return (
    <div className="p-6 bg-gray-50 min-h-screen font-sans">
      {/* Header & Search */}
      <div className="bg-white p-4 rounded-t-xl border-b border-gray-100 flex justify-between items-center gap-4">
        <h1 className="text-xl font-bold text-gray-800 flex items-center gap-2"><ShoppingBag className="text-blue-600"/> Đơn Hàng</h1>
        <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3 top-2.5 text-gray-400" size={18}/>
            <input 
                type="text" 
                placeholder="Tìm mã đơn, tên khách, SĐT..." 
                className="w-full pl-10 pr-4 py-2 border rounded-lg outline-none focus:ring-2 focus:ring-blue-500 transition text-sm"
                value={search}
                onChange={e => setSearch(e.target.value)}
            />
        </div>
        <button onClick={() => fetchOrders(1)} className="p-2 bg-gray-100 rounded hover:bg-gray-200 text-gray-600"><RefreshCw size={18}/></button>
      </div>

      {/* Tabs Navigation (Shopee Style) */}
      <div className="bg-white px-4 border-b border-gray-200 sticky top-0 z-10 flex overflow-x-auto no-scrollbar">
        {tabs.map(tab => (
            <button
                key={tab.id}
                onClick={() => setStatus(tab.id)}
                className={`py-4 px-6 text-sm font-medium whitespace-nowrap border-b-2 transition-colors ${
                    status === tab.id 
                    ? 'border-blue-600 text-blue-600' 
                    : 'border-transparent text-gray-500 hover:text-blue-600 hover:border-blue-200'
                }`}
            >
                {tab.label}
            </button>
        ))}
      </div>

      {/* Order List */}
      <div className="bg-white min-h-[500px] shadow-sm rounded-b-xl mb-10">
        {loading ? (
            <div className="flex justify-center items-center py-20 text-gray-500 gap-2"><Loader2 className="animate-spin"/> Đang tải dữ liệu...</div>
        ) : orders.length > 0 ? (
            <div className="divide-y divide-gray-100">
                {orders.map(order => (
                    <div key={order.id} className="p-4 hover:bg-blue-50/20 transition group">
                        {/* Row 1: Header Info */}
                        <div className="flex justify-between items-center mb-3">
                            <div className="flex items-center gap-3">
                                <Link href={`/orders/${order.code}`} className="font-bold text-blue-600 hover:underline">#{order.code}</Link>
                                <span className="text-gray-400">|</span>
                                <span className="text-sm font-medium text-gray-800">{order.customer_name}</span>
                                <span className="text-xs text-gray-500">({order.customer_phone})</span>
                            </div>
                            <div className="flex items-center gap-2">
                                <span className="text-xs text-gray-500">{new Date(order.created_at).toLocaleDateString('vi-VN')}</span>
                                <span className={`px-2 py-0.5 rounded text-xs font-bold uppercase border ${
                                    order.status === 'completed' ? 'bg-green-50 text-green-700 border-green-200' :
                                    order.status === 'cancelled' ? 'bg-red-50 text-red-700 border-red-200' :
                                    order.status === 'shipping' ? 'bg-purple-50 text-purple-700 border-purple-200' :
                                    'bg-orange-50 text-orange-700 border-orange-200'
                                }`}>
                                    {getStatusLabel(order.status)}
                                </span>
                            </div>
                        </div>

                        {/* Row 2: Content & Actions */}
                        <div className="flex justify-between items-end">
                            <div className="text-sm text-gray-600">
                                <div className="text-xs text-gray-400 mb-1">Tổng thanh toán:</div>
                                <div className="text-lg font-bold text-red-600">{new Intl.NumberFormat('vi-VN').format(order.total_amount)}đ</div>
                            </div>

                            {/* QUICK ACTIONS */}
                            <div className="flex gap-2">
                                <Link href={`/orders/${order.code}`} className="px-3 py-1.5 border border-gray-300 text-gray-600 rounded text-sm font-medium hover:bg-gray-50 flex items-center gap-1">
                                    <Eye size={14}/> Chi tiết
                                </Link>

                                {/* Action: Confirm (Pending -> Processing) */}
                                {order.status === 'pending' && (
                                    <>
                                        <button 
                                            onClick={() => handleQuickAction(order.id, 'cancelled')}
                                            disabled={processingId === order.id}
                                            className="px-3 py-1.5 border border-red-200 text-red-600 rounded text-sm font-medium hover:bg-red-50"
                                        >Hủy đơn</button>
                                        <button 
                                            onClick={() => handleQuickAction(order.id, 'processing')}
                                            disabled={processingId === order.id}
                                            className="px-4 py-1.5 bg-blue-600 text-white rounded text-sm font-bold hover:bg-blue-700 shadow-sm flex items-center gap-1"
                                        >
                                            {processingId === order.id ? <Loader2 size={14} className="animate-spin"/> : <PackageCheck size={16}/>} 
                                            Chuẩn bị hàng
                                        </button>
                                    </>
                                )}

                                {/* Action: Ship (Processing -> Shipping) */}
                                {order.status === 'processing' && (
                                    <button 
                                        onClick={() => handleQuickAction(order.id, 'shipping')}
                                        disabled={processingId === order.id}
                                        className="px-4 py-1.5 bg-orange-600 text-white rounded text-sm font-bold hover:bg-orange-700 shadow-sm flex items-center gap-1"
                                    >
                                        {processingId === order.id ? <Loader2 size={14} className="animate-spin"/> : <Truck size={16}/>} 
                                        Giao ĐVVC
                                    </button>
                                )}

                                {/* Action: Complete (Shipping -> Completed) */}
                                {order.status === 'shipping' && (
                                    <button 
                                        onClick={() => handleQuickAction(order.id, 'completed')}
                                        disabled={processingId === order.id}
                                        className="px-4 py-1.5 bg-green-600 text-white rounded text-sm font-bold hover:bg-green-700 shadow-sm flex items-center gap-1"
                                    >
                                        {processingId === order.id ? <Loader2 size={14} className="animate-spin"/> : <CheckCircle size={16}/>} 
                                        Đã giao xong
                                    </button>
                                )}
                            </div>
                        </div>
                    </div>
                ))}
            </div>
        ) : (
            <div className="flex flex-col justify-center items-center py-20 text-gray-400">
                <ShoppingBag size={48} className="mb-3 opacity-20"/>
                <p>Không có đơn hàng nào trong mục này.</p>
            </div>
        )}

        {/* Pagination */}
        {pagination && pagination.last_page > 1 && (
            <div className="p-4 border-t border-gray-100 flex justify-end gap-2 bg-gray-50 rounded-b-xl">
                <button 
                    disabled={pagination.current_page === 1} 
                    onClick={() => fetchOrders(pagination.current_page - 1)} 
                    className="px-3 py-1 bg-white border rounded hover:bg-gray-100 disabled:opacity-50 text-sm"
                >Trước</button>
                <span className="px-3 py-1 text-sm font-medium pt-1.5">Trang {pagination.current_page}</span>
                <button 
                    disabled={pagination.current_page === pagination.last_page} 
                    onClick={() => fetchOrders(pagination.current_page + 1)} 
                    className="px-3 py-1 bg-white border rounded hover:bg-gray-100 disabled:opacity-50 text-sm"
                >Sau</button>
            </div>
        )}
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# BUILD
# ==============================================================================
echo "🔄 Build Admin App..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Đã nâng cấp giao diện Orders Shopee Style!"
