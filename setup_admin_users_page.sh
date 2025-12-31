#!/bin/bash

echo "🚀 Đang xây dựng trang Quản lý User cho Admin..."

# ==============================================================================
# 1. BACKEND: Tạo UserController để quản lý User
# ==============================================================================
echo "⚙️ Tạo UserController (Backend)..."

mkdir -p /var/www/lica-project/backend/Modules/IAM/app/Http/Controllers

cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Http/Controllers/UserController.php
<?php

namespace Modules\IAM\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\Log;

class UserController extends Controller
{
    public function index(Request $request)
    {
        $query = User::query()->orderBy('created_at', 'desc');

        // Tìm kiếm
        if ($request->has('q') && !empty($request->q)) {
            $q = $request->q;
            $query->where(function($sub) use ($q) {
                $sub->where('name', 'like', "%{$q}%")
                    ->orWhere('email', 'like', "%{$q}%")
                    ->orWhere('phone', 'like', "%{$q}%")
                    ->orWhere('username', 'like', "%{$q}%");
            });
        }

        // Lọc theo Role (nếu sau này cần)
        // if ($request->role) $query->where('role', $request->role);

        $users = $query->paginate($request->get('limit', 20));

        return response()->json([
            'status' => 200,
            'data' => $users
        ]);
    }

    public function show($id)
    {
        $user = User::with(['addresses', 'orders'])->find($id);
        if (!$user) return response()->json(['message' => 'User not found'], 404);
        return response()->json(['status' => 200, 'data' => $user]);
    }

    public function destroy($id)
    {
        $user = User::find($id);
        if (!$user) return response()->json(['message' => 'User not found'], 404);
        
        // Không cho xóa admin chính (ví dụ ID 1)
        if ($id == 1) return response()->json(['message' => 'Không thể xóa Super Admin'], 403);

        $user->delete();
        return response()->json(['status' => 200, 'message' => 'Đã xóa thành viên']);
    }
}
EOF

# ==============================================================================
# 2. BACKEND: Đăng ký Route
# ==============================================================================
echo "🔗 Cập nhật Route API..."

# Kiểm tra xem route đã tồn tại chưa để tránh trùng lặp
if ! grep -q "UserController::class, 'index'" /var/www/lica-project/backend/Modules/IAM/routes/api.php; then
    cat << 'EOF' >> /var/www/lica-project/backend/Modules/IAM/routes/api.php

use Modules\IAM\Http\Controllers\UserController;

// Admin Management Routes
Route::prefix('v1/users')->group(function () {
    Route::get('/', [UserController::class, 'index']);
    Route::get('/{id}', [UserController::class, 'show']);
    Route::delete('/{id}', [UserController::class, 'destroy']);
});
EOF
fi

# ==============================================================================
# 3. FRONTEND ADMIN: Tạo trang Users
# ==============================================================================
echo "💻 Tạo giao diện Admin Users..."

mkdir -p /var/www/lica-project/apps/admin/app/users

cat << 'EOF' > /var/www/lica-project/apps/admin/app/users/page.tsx
"use client";

import { useState, useEffect, useCallback } from "react";
import axios from "axios";
import { 
  Search, Trash2, User, Mail, Phone, Calendar, Shield, MoreHorizontal, Loader2 
} from "lucide-react";
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
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [search]);

  useEffect(() => {
    // Debounce search
    const timer = setTimeout(() => {
        fetchUsers();
    }, 500);
    return () => clearTimeout(timer);
  }, [fetchUsers]);

  const handleDelete = async (id: number) => {
    if (!confirm("Bạn chắc chắn muốn xóa thành viên này? Hành động này không thể hoàn tác.")) return;
    try {
        await axios.delete(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/users/${id}`);
        fetchUsers(); // Reload
        alert("Đã xóa thành công!");
    } catch (err) {
        alert("Lỗi khi xóa thành viên (Có thể do quyền hạn hoặc ràng buộc dữ liệu).");
    }
  };

  return (
    <div className="p-6 max-w-7xl mx-auto bg-gray-50 min-h-screen font-sans">
      <div className="flex justify-between items-center mb-6">
        <div>
            <h1 className="text-2xl font-bold text-gray-800">Thành viên</h1>
            <p className="text-sm text-gray-500">Quản lý danh sách khách hàng & quản trị viên</p>
        </div>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        {/* Toolbar */}
        <div className="p-4 border-b border-gray-100 flex gap-4 bg-white">
            <div className="relative flex-1 max-w-md">
                <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
                <input 
                    type="text" 
                    placeholder="Tìm theo Tên, Email, SĐT..." 
                    className="w-full pl-10 pr-4 py-2 border rounded-lg outline-none focus:ring-2 focus:ring-blue-500 transition"
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                />
            </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
                <thead className="bg-gray-50 text-gray-600 text-xs uppercase font-semibold">
                    <tr>
                        <th className="px-6 py-4">Thành viên</th>
                        <th className="px-6 py-4">Liên hệ</th>
                        <th className="px-6 py-4">Vai trò / Hạng</th>
                        <th className="px-6 py-4">Ngày tham gia</th>
                        <th className="px-6 py-4 text-right">Hành động</th>
                    </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 text-sm">
                    {loading ? (
                        <tr><td colSpan={5} className="p-10 text-center"><Loader2 className="animate-spin inline text-blue-600"/> Đang tải dữ liệu...</td></tr>
                    ) : users.length > 0 ? (
                        users.map((user) => (
                            <tr key={user.id} className="hover:bg-gray-50 transition">
                                <td className="px-6 py-4">
                                    <div className="flex items-center gap-3">
                                        <div className="w-10 h-10 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center font-bold uppercase text-sm">
                                            {user.name ? user.name[0] : <User size={16}/>}
                                        </div>
                                        <div>
                                            <div className="font-bold text-gray-900">{user.name || "Chưa đặt tên"}</div>
                                            <div className="text-xs text-gray-500 font-mono">@{user.username}</div>
                                        </div>
                                    </div>
                                </td>
                                <td className="px-6 py-4">
                                    <div className="space-y-1">
                                        {user.email && <div className="flex items-center gap-2 text-gray-600"><Mail size={14}/> {user.email}</div>}
                                        {user.phone && <div className="flex items-center gap-2 text-gray-600"><Phone size={14}/> {user.phone}</div>}
                                    </div>
                                </td>
                                <td className="px-6 py-4">
                                    <div className="flex flex-col gap-1 items-start">
                                        <span className={`px-2 py-0.5 rounded text-xs font-bold uppercase border ${
                                            user.membership_tier === 'diamond' ? 'bg-purple-100 text-purple-700 border-purple-200' :
                                            user.membership_tier === 'gold' ? 'bg-yellow-100 text-yellow-700 border-yellow-200' :
                                            'bg-gray-100 text-gray-600 border-gray-200'
                                        }`}>
                                            {user.membership_tier || 'Member'}
                                        </span>
                                        {/* Nếu có role admin thì hiển thị thêm */}
                                        {user.role === 'admin' && <span className="text-xs flex items-center gap-1 text-red-600 font-bold"><Shield size={12}/> Admin</span>}
                                    </div>
                                </td>
                                <td className="px-6 py-4 text-gray-600">
                                    <div className="flex items-center gap-2">
                                        <Calendar size={14} className="text-gray-400"/>
                                        {new Date(user.created_at).toLocaleDateString('vi-VN')}
                                    </div>
                                </td>
                                <td className="px-6 py-4 text-right">
                                    <button 
                                        onClick={() => handleDelete(user.id)}
                                        className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition" 
                                        title="Xóa thành viên"
                                    >
                                        <Trash2 size={18}/>
                                    </button>
                                </td>
                            </tr>
                        ))
                    ) : (
                        <tr><td colSpan={5} className="p-10 text-center text-gray-500">Không tìm thấy thành viên nào.</td></tr>
                    )}
                </tbody>
            </table>
        </div>

        {/* Pagination */}
        {pagination && pagination.last_page > 1 && (
            <div className="p-4 border-t border-gray-100 flex justify-end gap-2">
                <button 
                    disabled={pagination.current_page === 1}
                    onClick={() => fetchUsers(pagination.current_page - 1)}
                    className="px-3 py-1 border rounded hover:bg-gray-50 disabled:opacity-50"
                >Trước</button>
                <span className="px-3 py-1 text-gray-600">Trang {pagination.current_page} / {pagination.last_page}</span>
                <button 
                    disabled={pagination.current_page === pagination.last_page}
                    onClick={() => fetchUsers(pagination.current_page + 1)}
                    className="px-3 py-1 border rounded hover:bg-gray-50 disabled:opacity-50"
                >Sau</button>
            </div>
        )}
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# 4. BUILD & RESTART
# ==============================================================================
echo "🔄 Build lại Admin App..."
cd /var/www/lica-project/backend
php artisan route:clear

cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Hoàn tất! Truy cập https://admin.lica.vn/users để xem danh sách."
