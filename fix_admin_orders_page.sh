#!/bin/bash

echo "🛠️ Đang sửa lỗi trang Quản lý Đơn hàng (Admin)..."

# ==============================================================================
# GHI ĐÈ TRANG ORDERS (Code chuẩn, xử lý lỗi an toàn)
# ==============================================================================
cat << 'EOF' > /var/www/lica-project/apps/admin/app/orders/page.tsx
"use client";

import { useState, useEffect, useCallback } from "react";
import axios from "axios";
import Link from "next/link";
import { ShoppingBag, Eye, Search, Filter, Loader2, RefreshCw } from "lucide-react";

// Định nghĩa kiểu dữ liệu để tránh lỗi truy xuất
interface Order {
  id: number;
  code: string;
  customer_name: string;
  customer_phone?: string;
  total_amount: number;
  status: string;
  payment_status: string;
  created_at: string;
}

export default function OrdersPage() {
  // State
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [pagination, setPagination] = useState<any>(null);
  const [filter, setFilter] = useState({ status: 'all', q: '' });

  // Fetch Data
  const fetchOrders = useCallback(async (page = 1) => {
    setLoading(true);
    try {
      const params = { 
        page, 
        q: filter.q, 
        status: filter.status !== 'all' ? filter.status : undefined 
      };
      
      const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/orders`, { params });
      
      // Safe check: Kiểm tra kỹ cấu trúc dữ liệu trước khi set state
      if (res.data && res.data.data && Array.isArray(res.data.data.data)) {
         setOrders(res.data.data.data);
         setPagination(res.data.data);
      } else {
         console.warn("API Orders trả về cấu trúc không mong đợi:", res.data);
         setOrders([]);
      }
    } catch (err) {
      console.error("Lỗi tải đơn hàng:", err);
      // Không crash app, chỉ hiện mảng rỗng
      setOrders([]);
    } finally {
      setLoading(false);
    }
  }, [filter]);

  // Effect: Debounce search
  useEffect(() => {
    const timer = setTimeout(() => fetchOrders(), 500); 
    return () => clearTimeout(timer);
  }, [fetchOrders]);

  // Helper: Màu trạng thái
  const getStatusColor = (status: string) => {
    switch(status) {
        case 'pending': return 'bg-yellow-100 text-yellow-700';
        case 'processing': return 'bg-blue-100 text-blue-700';
        case 'shipping': return 'bg-purple-100 text-purple-700';
        case 'completed': return 'bg-green-100 text-green-700';
        case 'cancelled': return 'bg-red-100 text-red-700';
        default: return 'bg-gray-100 text-gray-600';
    }
  };

  const getStatusLabel = (status: string) => {
     const map: any = {
         pending: 'Chờ xử lý', processing: 'Đang chuẩn bị', shipping: 'Đang giao',
         completed: 'Hoàn thành', cancelled: 'Đã hủy'
     };
     return map[status] || status;
  };

  return (
    <div className="p-6 bg-gray-50 min-h-screen font-sans">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center mb-6 gap-4">
        <div>
            <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2"><ShoppingBag className="text-blue-600"/> Quản lý Đơn hàng</h1>
            <p className="text-sm text-gray-500 mt-1">Danh sách đơn đặt hàng từ hệ thống</p>
        </div>
        <button onClick={() => fetchOrders(1)} className="p-2 bg-white border rounded hover:bg-gray-50 text-gray-600" title="Tải lại">
            <RefreshCw size={18}/>
        </button>
      </div>

      {/* Toolbar */}
      <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-200 mb-6 flex flex-col sm:flex-row gap-4">
         <div className="relative flex-1">
            <Search className="absolute left-3 top-2.5 text-gray-400" size={18}/>
            <input 
                type="text" 
                placeholder="Tìm mã đơn, tên khách, SĐT..." 
                className="w-full pl-10 pr-4 py-2 border rounded-lg outline-none focus:ring-2 focus:ring-blue-500 transition"
                value={filter.q}
                onChange={e => setFilter({...filter, q: e.target.value})}
            />
         </div>
         <div className="relative min-w-[200px]">
            <Filter className="absolute left-3 top-2.5 text-gray-400" size={18}/>
            <select 
                className="w-full pl-10 pr-4 py-2 border rounded-lg outline-none focus:ring-2 focus:ring-blue-500 appearance-none bg-white cursor-pointer"
                value={filter.status}
                onChange={e => setFilter({...filter, status: e.target.value})}
            >
                <option value="all">Tất cả trạng thái</option>
                <option value="pending">Chờ xử lý</option>
                <option value="processing">Đang chuẩn bị</option>
                <option value="shipping">Đang giao hàng</option>
                <option value="completed">Hoàn thành</option>
                <option value="cancelled">Đã hủy</option>
            </select>
         </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
                <thead className="bg-gray-50 text-gray-600 font-bold uppercase text-xs border-b border-gray-200">
                    <tr>
                        <th className="p-4">Mã đơn</th>
                        <th className="p-4">Khách hàng</th>
                        <th className="p-4">Tổng tiền</th>
                        <th className="p-4">Trạng thái</th>
                        <th className="p-4">Ngày đặt</th>
                        <th className="p-4 text-right">Thao tác</th>
                    </tr>
                </thead>
                <tbody className="divide-y divide-gray-100">
                    {loading ? (
                        <tr><td colSpan={6} className="p-12 text-center text-gray-500"><Loader2 className="animate-spin inline text-blue-600 mr-2"/> Đang tải dữ liệu...</td></tr>
                    ) : orders.length > 0 ? (
                        orders.map(order => (
                            <tr key={order.id} className="hover:bg-blue-50/30 transition group">
                                <td className="p-4 font-bold text-blue-600">#{order.code}</td>
                                <td className="p-4">
                                    <div className="font-medium text-gray-900">{order.customer_name}</div>
                                    <div className="text-xs text-gray-500 font-mono">{order.customer_phone}</div>
                                </td>
                                <td className="p-4 font-bold text-gray-800 text-base">
                                    {new Intl.NumberFormat('vi-VN').format(order.total_amount)}đ
                                </td>
                                <td className="p-4">
                                    <div className="flex flex-col items-start gap-1">
                                        <span className={`px-2.5 py-1 rounded-full text-[11px] font-bold uppercase tracking-wide ${getStatusColor(order.status)}`}>
                                            {getStatusLabel(order.status)}
                                        </span>
                                    </div>
                                </td>
                                <td className="p-4 text-gray-500 text-xs">
                                    {new Date(order.created_at).toLocaleDateString('vi-VN')}
                                    <div className="text-[10px] text-gray-400">{new Date(order.created_at).toLocaleTimeString('vi-VN')}</div>
                                </td>
                                <td className="p-4 text-right">
                                    <Link href={`/orders/${order.code}`} className="inline-flex items-center gap-1 px-3 py-1.5 border border-blue-200 text-blue-600 rounded-lg hover:bg-blue-600 hover:text-white font-medium transition shadow-sm">
                                        <Eye size={16}/> Chi tiết
                                    </Link>
                                </td>
                            </tr>
                        ))
                    ) : (
                        <tr><td colSpan={6} className="p-12 text-center text-gray-400 flex flex-col items-center justify-center w-full">
                            <ShoppingBag size={48} className="text-gray-200 mb-2"/>
                            Chưa tìm thấy đơn hàng nào.
                        </td></tr>
                    )}
                </tbody>
            </table>
        </div>
        
        {/* Pagination */}
        {pagination && pagination.last_page > 1 && (
            <div className="p-4 border-t border-gray-100 flex justify-end items-center gap-2 bg-gray-50">
                <button 
                    disabled={pagination.current_page === 1} 
                    onClick={() => fetchOrders(pagination.current_page - 1)} 
                    className="px-3 py-1.5 border bg-white rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
                >Trước</button>
                <span className="px-3 py-1 text-sm text-gray-600 font-medium">Trang {pagination.current_page} / {pagination.last_page}</span>
                <button 
                    disabled={pagination.current_page === pagination.last_page} 
                    onClick={() => fetchOrders(pagination.current_page + 1)} 
                    className="px-3 py-1.5 border bg-white rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed text-sm"
                >Sau</button>
            </div>
        )}
      </div>
    </div>
  );
}
EOF

echo "🔄 Build lại Admin App..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Đã sửa lỗi! Hãy tải lại trang https://admin.lica.vn/orders"
