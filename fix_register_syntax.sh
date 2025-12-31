#!/bin/bash

echo "🛠️ Đang sửa lỗi cú pháp trang Đăng ký (Frontend)..."

# Ghi đè file apps/user/app/register/page.tsx với code chuẩn
cat << 'EOF' > /var/www/lica-project/apps/user/app/register/page.tsx
"use client";
import { useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";

export default function RegisterPage() {
  const router = useRouter();
  // Form rút gọn: Chỉ cần email/sdt và password
  const [formData, setFormData] = useState({ email_or_phone: "", password: "" });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      // CODE ĐÃ ĐƯỢC SỬA: Loại bỏ các ký tự backslash thừa
      const res = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/auth/register`, formData);
      
      if (res.data.status === 200) {
        localStorage.setItem("token", res.data.access_token);
        localStorage.setItem("user", JSON.stringify(res.data.data));
        // Chuyển hướng đến trang profile với username tự động
        router.push(`/profile/${res.data.data.username}`);
      }
    } catch (err: any) {
      console.error(err);
      setError(err.response?.data?.message || "Đăng ký thất bại. Vui lòng kiểm tra lại thông tin.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4 font-sans">
      <div className="max-w-md w-full bg-white rounded-xl shadow-lg p-8">
        <h1 className="text-2xl font-bold text-center text-gray-800 mb-2">Đăng ký nhanh</h1>
        <p className="text-center text-gray-500 text-sm mb-6">Tạo tài khoản để theo dõi đơn hàng dễ dàng hơn</p>
        
        <form onSubmit={handleRegister} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email hoặc Số điện thoại</label>
            <input 
              type="text" 
              required 
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:ring-2 focus:ring-blue-500 transition" 
              placeholder="Ví dụ: 0912345678"
              value={formData.email_or_phone} 
              onChange={e => setFormData({...formData, email_or_phone: e.target.value})} 
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mật khẩu</label>
            <input 
              type="password" 
              required 
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:ring-2 focus:ring-blue-500 transition" 
              placeholder="Tối thiểu 6 ký tự"
              value={formData.password} 
              onChange={e => setFormData({...formData, password: e.target.value})} 
            />
          </div>
          
          {error && <div className="p-3 bg-red-50 text-red-600 text-sm rounded-lg border border-red-100">{error}</div>}
          
          <button type="submit" disabled={loading} className="w-full bg-blue-600 text-white font-bold py-3 rounded-lg hover:bg-blue-700 transition disabled:opacity-70 shadow-sm mt-2">
            {loading ? "Đang tạo tài khoản..." : "Đăng ký ngay"}
          </button>
        </form>
        
        <div className="text-center mt-6 pt-6 border-t border-gray-100">
          <p className="text-sm text-gray-600">
            Đã có tài khoản? <Link href="/login" className="text-blue-600 font-medium hover:underline">Đăng nhập</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
EOF

echo "🔄 Build lại User App..."
cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Đã sửa lỗi xong! Bạn hãy thử đăng ký lại tại http://lica.vn/register"
