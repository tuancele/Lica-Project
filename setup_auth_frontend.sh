#!/bin/bash

echo "🚀 Đang thiết lập Frontend Auth & Profile..."

# 1. Tạo thư mục
mkdir -p /var/www/lica-project/apps/user/app/login
mkdir -p /var/www/lica-project/apps/user/app/register
mkdir -p /var/www/lica-project/apps/user/app/profile/[username]
mkdir -p /var/www/lica-project/apps/user/components/profile

# 2. Trang Đăng Nhập (/login)
cat << 'EOF' > /var/www/lica-project/apps/user/app/login/page.tsx
"use client";
import { useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";

export default function LoginPage() {
  const router = useRouter();
  const [formData, setFormData] = useState({ email_or_phone: "", password: "" });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const res = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/auth/login`, formData);
      if (res.data.status === 200) {
        localStorage.setItem("token", res.data.access_token);
        localStorage.setItem("user", JSON.stringify(res.data.data));
        // Redirect về trang profile của user
        router.push(`/profile/${res.data.data.username}`);
      }
    } catch (err: any) {
      setError(err.response?.data?.message || "Đăng nhập thất bại");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4">
      <div className="max-w-md w-full bg-white rounded-xl shadow-lg p-8">
        <h1 className="text-2xl font-bold text-center text-gray-800 mb-6">Đăng nhập</h1>
        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email hoặc Số điện thoại</label>
            <input type="text" required className="w-full border rounded-lg px-4 py-2 outline-none focus:ring-2 focus:ring-blue-500" 
              value={formData.email_or_phone} onChange={e => setFormData({...formData, email_or_phone: e.target.value})} />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mật khẩu</label>
            <input type="password" required className="w-full border rounded-lg px-4 py-2 outline-none focus:ring-2 focus:ring-blue-500" 
              value={formData.password} onChange={e => setFormData({...formData, password: e.target.value})} />
          </div>
          {error && <p className="text-red-500 text-sm">{error}</p>}
          <button type="submit" disabled={loading} className="w-full bg-blue-600 text-white font-bold py-2.5 rounded-lg hover:bg-blue-700 transition disabled:opacity-50">
            {loading ? "Đang xử lý..." : "Đăng nhập"}
          </button>
        </form>
        <p className="text-center mt-4 text-sm text-gray-600">
          Chưa có tài khoản? <Link href="/register" className="text-blue-600 hover:underline">Đăng ký ngay</Link>
        </p>
      </div>
    </div>
  );
}
EOF

# 3. Trang Đăng Ký (/register)
cat << 'EOF' > /var/www/lica-project/apps/user/app/register/page.tsx
"use client";
import { useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";

export default function RegisterPage() {
  const router = useRouter();
  const [formData, setFormData] = useState({ name: "", username: "", email_or_phone: "", password: "" });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const res = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/auth/register`, formData);
      if (res.data.status === 200) {
        localStorage.setItem("token", res.data.access_token);
        localStorage.setItem("user", JSON.stringify(res.data.data));
        router.push(`/profile/${res.data.data.username}`);
      }
    } catch (err: any) {
      setError(err.response?.data?.message || "Đăng ký thất bại");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4">
      <div className="max-w-md w-full bg-white rounded-xl shadow-lg p-8">
        <h1 className="text-2xl font-bold text-center text-gray-800 mb-6">Đăng ký tài khoản</h1>
        <form onSubmit={handleRegister} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Họ và tên</label>
            <input type="text" required className="w-full border rounded-lg px-4 py-2" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Username (để tạo URL profile)</label>
            <input type="text" required className="w-full border rounded-lg px-4 py-2" placeholder="tuancele" value={formData.username} onChange={e => setFormData({...formData, username: e.target.value})} />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email hoặc Số điện thoại</label>
            <input type="text" required className="w-full border rounded-lg px-4 py-2" value={formData.email_or_phone} onChange={e => setFormData({...formData, email_or_phone: e.target.value})} />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mật khẩu</label>
            <input type="password" required className="w-full border rounded-lg px-4 py-2" value={formData.password} onChange={e => setFormData({...formData, password: e.target.value})} />
          </div>
          {error && <p className="text-red-500 text-sm">{error}</p>}
          <button type="submit" disabled={loading} className="w-full bg-blue-600 text-white font-bold py-2.5 rounded-lg hover:bg-blue-700 disabled:opacity-50">
            {loading ? "Đang xử lý..." : "Đăng ký"}
          </button>
        </form>
        <p className="text-center mt-4 text-sm text-gray-600">
          Đã có tài khoản? <Link href="/login" className="text-blue-600 hover:underline">Đăng nhập</Link>
        </p>
      </div>
    </div>
  );
}
EOF

# 4. Trang Profile (/profile/[username])
cat << 'EOF' > /var/www/lica-project/apps/user/app/profile/[username]/page.tsx
"use client";
import { useState, useEffect, use } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { User, Package, MapPin, Heart, Award, LogOut } from "lucide-react";

export default function ProfilePage({ params }: { params: Promise<{ username: string }> }) {
  const { username } = use(params);
  const router = useRouter();
  const [user, setUser] = useState<any>(null);
  const [activeTab, setActiveTab] = useState("profile");
  const [orders, setOrders] = useState<any[]>([]);
  const [addresses, setAddresses] = useState<any[]>([]);
  
  // Kiểm tra Auth & Load Data
  useEffect(() => {
    const token = localStorage.getItem("token");
    if (!token) {
      router.push("/login");
      return;
    }

    const fetchData = async () => {
      try {
        const headers = { Authorization: `Bearer ${token}` };
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        
        // 1. Lấy thông tin user
        const meRes = await axios.get(`${apiUrl}/api/v1/profile/me`, { headers });
        setUser(meRes.data.data);

        // 2. Lấy dữ liệu theo Tab
        if (activeTab === "orders") {
          const orderRes = await axios.get(`${apiUrl}/api/v1/profile/orders`, { headers });
          setOrders(orderRes.data.data);
        }
        if (activeTab === "address") {
          const addrRes = await axios.get(`${apiUrl}/api/v1/profile/addresses`, { headers });
          setAddresses(addrRes.data.data);
        }

      } catch (err) {
        console.error(err);
        localStorage.removeItem("token");
        router.push("/login");
      }
    };
    
    fetchData();
  }, [activeTab, router]);

  const handleLogout = () => {
    localStorage.removeItem("token");
    localStorage.removeItem("user");
    router.push("/login");
  };

  if (!user) return <div className="p-10 text-center">Đang tải hồ sơ...</div>;

  return (
    <div className="min-h-screen bg-gray-50 p-6 font-sans">
      <div className="max-w-5xl mx-auto grid grid-cols-1 md:grid-cols-4 gap-6">
        
        {/* Sidebar Menu */}
        <div className="bg-white rounded-xl shadow-sm p-6 h-fit">
          <div className="flex items-center gap-3 mb-6 pb-6 border-b">
            <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 font-bold text-xl uppercase">
              {user.name[0]}
            </div>
            <div>
              <div className="font-bold text-gray-900">{user.name}</div>
              <div className="text-xs text-gray-500">@{user.username}</div>
            </div>
          </div>
          <nav className="space-y-2">
            <button onClick={() => setActiveTab("profile")} className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition ${activeTab === "profile" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}`}>
              <User size={18} /> Hồ sơ của tôi
            </button>
            <button onClick={() => setActiveTab("orders")} className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition ${activeTab === "orders" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}`}>
              <Package size={18} /> Đơn hàng
            </button>
            <button onClick={() => setActiveTab("tier")} className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition ${activeTab === "tier" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}`}>
              <Award size={18} /> Hạng thành viên
            </button>
            <button onClick={() => setActiveTab("address")} className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition ${activeTab === "address" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}`}>
              <MapPin size={18} /> Địa chỉ giao hàng
            </button>
            <button onClick={() => setActiveTab("wishlist")} className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition ${activeTab === "wishlist" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}`}>
              <Heart size={18} /> Wishlist
            </button>
            <button onClick={handleLogout} className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg text-red-600 hover:bg-red-50 mt-4 border-t pt-4">
              <LogOut size={18} /> Đăng xuất
            </button>
          </nav>
        </div>

        {/* Content Area */}
        <div className="md:col-span-3 bg-white rounded-xl shadow-sm p-8">
          
          {/* TAB: PROFILE */}
          {activeTab === "profile" && (
            <div>
              <h2 className="text-xl font-bold text-gray-800 mb-6 pb-4 border-b">Hồ sơ của tôi</h2>
              <div className="space-y-4 max-w-lg">
                <div className="grid grid-cols-3 gap-4 items-center">
                  <span className="text-gray-500">Tên hiển thị</span>
                  <span className="col-span-2 font-medium">{user.name}</span>
                </div>
                <div className="grid grid-cols-3 gap-4 items-center">
                  <span className="text-gray-500">Email / SĐT</span>
                  <span className="col-span-2 font-medium">{user.email || user.phone}</span>
                </div>
                <div className="grid grid-cols-3 gap-4 items-center">
                  <span className="text-gray-500">Hạng thành viên</span>
                  <span className="col-span-2 inline-block px-3 py-1 bg-yellow-100 text-yellow-700 rounded-full text-xs font-bold uppercase">{user.membership_tier}</span>
                </div>
              </div>
            </div>
          )}

          {/* TAB: ORDERS */}
          {activeTab === "orders" && (
            <div>
              <h2 className="text-xl font-bold text-gray-800 mb-6 pb-4 border-b">Đơn hàng của tôi</h2>
              <div className="space-y-4">
                {orders.length > 0 ? orders.map((order) => (
                  <div key={order.id} className="border rounded-lg p-4 hover:shadow-sm transition">
                    <div className="flex justify-between items-center mb-3">
                      <span className="font-mono text-gray-500">#{order.code}</span>
                      <span className={`px-2 py-1 rounded text-xs uppercase font-bold ${
                        order.status === 'completed' ? 'bg-green-100 text-green-700' : 
                        order.status === 'pending' ? 'bg-orange-100 text-orange-700' : 'bg-gray-100 text-gray-600'
                      }`}>{order.status}</span>
                    </div>
                    <div className="text-sm text-gray-600 mb-2">
                      {new Date(order.created_at).toLocaleDateString('vi-VN')}
                    </div>
                    <div className="flex justify-between items-center border-t pt-3">
                      <span className="text-sm text-gray-500">{order.items?.length} sản phẩm</span>
                      <span className="font-bold text-red-600">{new Intl.NumberFormat('vi-VN').format(order.total_amount)}đ</span>
                    </div>
                  </div>
                )) : <p className="text-gray-500">Chưa có đơn hàng nào.</p>}
              </div>
            </div>
          )}

          {/* TAB: ADDRESS */}
          {activeTab === "address" && (
            <div>
              <h2 className="text-xl font-bold text-gray-800 mb-6 pb-4 border-b">Địa chỉ giao hàng</h2>
              {addresses.length > 0 ? addresses.map(addr => (
                <div key={addr.id} className="border p-4 rounded-lg mb-3">
                  <div className="font-bold">{addr.name} | {addr.phone}</div>
                  <div className="text-gray-600">{addr.address}</div>
                  {addr.is_default && <span className="text-xs text-blue-600 border border-blue-600 px-2 rounded mt-1 inline-block">Mặc định</span>}
                </div>
              )) : <p className="text-gray-500">Chưa có địa chỉ nào.</p>}
              <button className="mt-4 px-4 py-2 border border-blue-600 text-blue-600 rounded-lg hover:bg-blue-50 font-medium">+ Thêm địa chỉ mới</button>
            </div>
          )}

          {/* TAB: TIER */}
          {activeTab === "tier" && (
            <div className="text-center py-10">
              <Award size={64} className="mx-auto text-yellow-500 mb-4" />
              <h3 className="text-xl font-bold text-gray-800 uppercase">{user.membership_tier}</h3>
              <p className="text-gray-500 mt-2">Điểm tích lũy: <span className="font-bold text-blue-600">{user.points || 0} điểm</span></p>
            </div>
          )}

          {/* TAB: WISHLIST */}
          {activeTab === "wishlist" && (
            <div className="text-center text-gray-500 py-10">
              <Heart size={48} className="mx-auto mb-3 text-gray-300" />
              <p>Danh sách yêu thích trống.</p>
            </div>
          )}

        </div>
      </div>
    </div>
  );
}
EOF

# 5. Build & Restart User App
echo "🔄 Đang build lại User App..."
cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Hoàn tất! Truy cập /register để tạo tài khoản ngay."
