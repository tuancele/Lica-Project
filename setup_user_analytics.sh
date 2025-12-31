#!/bin/bash

echo "🚀 Đang xây dựng trang Chi tiết & Phân tích User..."

# ==============================================================================
# 1. BACKEND: Nâng cấp UserController (Thêm số liệu phân tích)
# ==============================================================================
echo "⚙️ Cập nhật Backend: Tính toán chỉ số tài chính User..."

cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Http/Controllers/UserController.php
<?php

namespace Modules\IAM\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class UserController extends Controller
{
    public function index(Request $request)
    {
        $query = User::query()->orderBy('created_at', 'desc');

        if ($request->has('q') && !empty($request->q)) {
            $q = $request->q;
            $query->where(function($sub) use ($q) {
                $sub->where('name', 'like', "%{$q}%")
                    ->orWhere('email', 'like', "%{$q}%")
                    ->orWhere('phone', 'like', "%{$q}%")
                    ->orWhere('username', 'like', "%{$q}%");
            });
        }

        $users = $query->paginate($request->get('limit', 20));

        return response()->json(['status' => 200, 'data' => $users]);
    }

    public function show($id)
    {
        // Load User kèm Địa chỉ và Đơn hàng (sắp xếp đơn mới nhất)
        $user = User::with(['addresses', 'orders' => function($q) {
            $q->orderBy('created_at', 'desc');
        }])->find($id);

        if (!$user) return response()->json(['message' => 'User not found'], 404);

        // --- PHÂN TÍCH SỐ LIỆU ---
        
        // 1. Tổng chi tiêu (Chỉ tính đơn đã hoàn thành)
        $totalSpent = $user->orders->where('status', 'completed')->sum('total_amount');
        
        // 2. Thống kê số lượng đơn
        $totalOrders = $user->orders->count();
        $completedOrders = $user->orders->where('status', 'completed')->count();
        $cancelledOrders = $user->orders->where('status', 'cancelled')->count();

        // 3. Giá trị trung bình đơn hàng (AOV)
        $aov = $completedOrders > 0 ? $totalSpent / $completedOrders : 0;

        // Gắn thêm dữ liệu vào response
        $user->analytics = [
            'total_spent' => $totalSpent,
            'total_orders' => $totalOrders,
            'completed_orders' => $completedOrders,
            'cancelled_orders' => $cancelledOrders,
            'aov' => $aov // Average Order Value
        ];

        return response()->json(['status' => 200, 'data' => $user]);
    }

    public function destroy($id)
    {
        if ($id == 1) return response()->json(['message' => 'Cannot delete Super Admin'], 403);
        $user = User::find($id);
        if (!$user) return response()->json(['message' => 'User not found'], 404);
        $user->delete();
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
EOF

# ==============================================================================
# 2. FRONTEND: Cập nhật trang Danh sách (Thêm Link vào chi tiết)
# ==============================================================================
echo "💻 Cập nhật trang Danh sách User (Thêm liên kết)..."
# Chúng ta sẽ ghi đè lại trang Users Page cũ để thêm Link href
cat << 'EOF' > /var/www/lica-project/apps/admin/app/users/page.tsx
"use client";

import { useState, useEffect, useCallback } from "react";
import axios from "axios";
import { Search, Trash2, User, Mail, Phone, Calendar, Shield, Eye, Loader2 } from "lucide-react";
import Link from "next/link";

export default function UsersPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [pagination, setPagination] = useState<any>(null);
  const [search, setSearch] = useState("");

  const fetchUsers = useCallback(async (page = 1) => {
    try {
      setLoading(true);
      const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/users`, {
        params: { page, q: search }
      });
      setUsers(res.data.data.data);
      setPagination(res.data.data);
    } catch (err) { console.error(err); } finally { setLoading(false); }
  }, [search]);

  useEffect(() => {
    const timer = setTimeout(() => fetchUsers(), 500);
    return () => clearTimeout(timer);
  }, [fetchUsers]);

  const handleDelete = async (id: number) => {
    if (!confirm("Bạn chắc chắn muốn xóa?")) return;
    try {
        await axios.delete(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/users/${id}`);
        fetchUsers();
    } catch (err) { alert("Lỗi khi xóa."); }
  };

  return (
    <div className="p-6 max-w-7xl mx-auto bg-gray-50 min-h-screen font-sans">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Thành viên</h1>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="p-4 border-b border-gray-100 flex gap-4 bg-white">
            <div className="relative flex-1 max-w-md">
                <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
                <input type="text" placeholder="Tìm thành viên..." className="w-full pl-10 pr-4 py-2 border rounded-lg outline-none focus:ring-2 focus:ring-blue-500"
                    value={search} onChange={(e) => setSearch(e.target.value)} />
            </div>
        </div>

        <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
                <thead className="bg-gray-50 text-gray-600 text-xs uppercase font-semibold">
                    <tr>
                        <th className="px-6 py-4">Thành viên</th>
                        <th className="px-6 py-4">Liên hệ</th>
                        <th className="px-6 py-4">Hạng</th>
                        <th className="px-6 py-4">Ngày tham gia</th>
                        <th className="px-6 py-4 text-right">Hành động</th>
                    </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 text-sm">
                    {loading ? (
                        <tr><td colSpan={5} className="p-10 text-center"><Loader2 className="animate-spin inline text-blue-600"/></td></tr>
                    ) : users.length > 0 ? (
                        users.map((user) => (
                            <tr key={user.id} className="hover:bg-gray-50 transition group">
                                <td className="px-6 py-4">
                                    <Link href={`/users/${user.id}`} className="flex items-center gap-3 group-hover:text-blue-600">
                                        <div className="w-10 h-10 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center font-bold uppercase text-sm">
                                            {user.name ? user.name[0] : <User size={16}/>}
                                        </div>
                                        <div>
                                            <div className="font-bold text-gray-900 group-hover:text-blue-600 transition">{user.name || "N/A"}</div>
                                            <div className="text-xs text-gray-500 font-mono">@{user.username}</div>
                                        </div>
                                    </Link>
                                </td>
                                <td className="px-6 py-4">
                                    <div className="space-y-1 text-gray-600">
                                        {user.email && <div className="flex items-center gap-2"><Mail size={14}/> {user.email}</div>}
                                        {user.phone && <div className="flex items-center gap-2"><Phone size={14}/> {user.phone}</div>}
                                    </div>
                                </td>
                                <td className="px-6 py-4">
                                    <span className="px-2 py-1 rounded text-xs font-bold uppercase bg-gray-100 text-gray-600">{user.membership_tier}</span>
                                </td>
                                <td className="px-6 py-4 text-gray-600">{new Date(user.created_at).toLocaleDateString('vi-VN')}</td>
                                <td className="px-6 py-4 text-right">
                                    <div className="flex justify-end gap-2">
                                        <Link href={`/users/${user.id}`} className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg"><Eye size={18}/></Link>
                                        <button onClick={() => handleDelete(user.id)} className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg"><Trash2 size={18}/></button>
                                    </div>
                                </td>
                            </tr>
                        ))
                    ) : (
                        <tr><td colSpan={5} className="p-10 text-center text-gray-500">Không tìm thấy thành viên.</td></tr>
                    )}
                </tbody>
            </table>
        </div>
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# 3. FRONTEND: Tạo trang Chi tiết User (Phân tích đầy đủ)
# ==============================================================================
echo "💻 Tạo trang Chi tiết User ([id]/page.tsx)..."

mkdir -p /var/www/lica-project/apps/admin/app/users/[id]

cat << 'EOF' > /var/www/lica-project/apps/admin/app/users/[id]/page.tsx
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
EOF

# ==============================================================================
# 4. BUILD
# ==============================================================================
echo "🔄 Build lại Admin App..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Hoàn tất! Truy cập danh sách User và bấm vào tên để xem chi tiết."
