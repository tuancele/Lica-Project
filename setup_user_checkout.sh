#!/bin/bash

echo "🚀 Đang thiết lập giao diện Đặt hàng (User Frontend)..."

# 1. Tạo thư mục
mkdir -p /var/www/lica-project/apps/user/app/order/shipping
mkdir -p /var/www/lica-project/apps/user/app/order/success/[hash]
mkdir -p /var/www/lica-project/apps/user/types

# 2. Tạo Type định nghĩa dữ liệu (Types)
echo "📝 Tạo Types..."
cat << 'EOF' > /var/www/lica-project/apps/user/types/order.ts
export interface OrderItemInput {
  product_id: number;
  quantity: number;
}

export interface CheckoutPayload {
  customer_name: string;
  customer_phone: string;
  customer_email: string;
  shipping_address: string;
  payment_method: string;
  items: OrderItemInput[];
}

export interface OrderSuccessData {
  id: number;
  code: string;
  customer_name: string;
  total_amount: string;
  payment_method: string;
  items: any[];
}
EOF

# 3. Tạo Trang Nhập thông tin giao hàng (/order/shipping)
echo "📝 Tạo trang Checkout..."
cat << 'EOF' > /var/www/lica-project/apps/user/app/order/shipping/page.tsx
"use client";

import { useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";

export default function ShippingPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  // State form nhập liệu
  const [formData, setFormData] = useState({
    customer_name: "",
    customer_phone: "",
    customer_email: "",
    shipping_address: "",
    payment_method: "cash_on_delivery",
    note: ""
  });

  // Giả lập giỏ hàng (Thực tế sẽ lấy từ LocalStorage hoặc Context)
  const cartItems = [
    { product_id: 1, quantity: 1, name: "Sản phẩm Test (Demo)", price: 500000 }
  ];

  const totalAmount = cartItems.reduce((acc, item) => acc + (item.price * item.quantity), 0);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    try {
      const payload = {
        ...formData,
        items: cartItems.map(item => ({ product_id: item.product_id, quantity: item.quantity }))
      };

      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.lica.vn";
      const res = await axios.post(`${apiUrl}/api/v1/order/checkout`, payload);

      if (res.data.status === 200) {
        // Chuyển hướng sang trang cảm ơn bằng URL trả về từ Backend
        const redirectUrl = res.data.data.redirect_url; // Đã bao gồm /order/success/...
        router.push(redirectUrl);
      }
    } catch (err: any) {
      console.error(err);
      setError(err.response?.data?.message || "Có lỗi xảy ra khi đặt hàng.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 p-4 font-sans">
      <div className="max-w-3xl mx-auto bg-white shadow-sm rounded-xl overflow-hidden border border-gray-100">
        <div className="bg-blue-600 p-4 text-white text-center">
          <h1 className="text-xl font-bold">Xác nhận đơn hàng</h1>
        </div>
        
        <div className="p-6 grid md:grid-cols-2 gap-8">
          {/* Cột trái: Form nhập liệu */}
          <form onSubmit={handleSubmit} className="space-y-4">
            <h2 className="font-bold text-gray-800 border-b pb-2 mb-4">Thông tin giao hàng</h2>
            
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Họ và tên *</label>
              <input type="text" name="customer_name" required className="w-full border rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500" placeholder="Nguyễn Văn A" onChange={handleChange} />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Số điện thoại *</label>
              <input type="tel" name="customer_phone" required className="w-full border rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500" placeholder="09xxxxxx" onChange={handleChange} />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Email (Tùy chọn)</label>
              <input type="email" name="customer_email" className="w-full border rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500" placeholder="email@example.com" onChange={handleChange} />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Địa chỉ nhận hàng *</label>
              <textarea name="shipping_address" required rows={2} className="w-full border rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500" placeholder="Số nhà, đường, phường/xã..." onChange={handleChange} />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Phương thức thanh toán</label>
              <select name="payment_method" className="w-full border rounded-lg px-3 py-2 bg-white" onChange={handleChange}>
                <option value="cash_on_delivery">Thanh toán khi nhận hàng (COD)</option>
                <option value="banking">Chuyển khoản ngân hàng</option>
              </select>
            </div>

            {error && <div className="p-3 bg-red-50 text-red-600 text-sm rounded-lg">{error}</div>}

            <button type="submit" disabled={loading} className="w-full bg-red-600 text-white font-bold py-3 rounded-lg hover:bg-red-700 transition disabled:opacity-70">
              {loading ? "Đang xử lý..." : `ĐẶT HÀNG (${new Intl.NumberFormat('vi-VN').format(totalAmount)}đ)`}
            </button>
          </form>

          {/* Cột phải: Tóm tắt đơn hàng */}
          <div className="bg-gray-50 p-4 rounded-lg h-fit">
            <h2 className="font-bold text-gray-800 border-b pb-2 mb-4">Đơn hàng của bạn</h2>
            <div className="space-y-3">
              {cartItems.map((item, idx) => (
                <div key={idx} className="flex justify-between text-sm">
                  <span>{item.name} <span className="text-gray-500">x{item.quantity}</span></span>
                  <span className="font-medium">{new Intl.NumberFormat('vi-VN').format(item.price * item.quantity)}đ</span>
                </div>
              ))}
            </div>
            <div className="border-t mt-4 pt-4 flex justify-between font-bold text-lg text-red-600">
              <span>Tổng cộng</span>
              <span>{new Intl.NumberFormat('vi-VN').format(totalAmount)}đ</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

# 4. Tạo Trang Thành công (/order/success/[hash])
echo "📝 Tạo trang Success..."
cat << 'EOF' > /var/www/lica-project/apps/user/app/order/success/[hash]/page.tsx
"use client";

import { useEffect, useState, use } from "react";
import axios from "axios";
import Link from "next/link";
import { useSearchParams } from "next/navigation";

// Next.js 16 uses Promise for params
export default function OrderSuccessPage({ params }: { params: Promise<{ hash: string }> }) {
  const { hash } = use(params);
  const searchParams = useSearchParams();
  const [order, setOrder] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  // Lấy thông tin sơ bộ từ URL params để hiển thị ngay (UX tốt hơn)
  const totalParam = searchParams.get('total');
  const methodParam = searchParams.get('method');

  useEffect(() => {
    const fetchOrder = async () => {
      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.lica.vn";
        const res = await axios.get(`${apiUrl}/api/v1/order/success/${hash}`);
        setOrder(res.data.data);
      } catch (err) {
        console.error("Lỗi lấy thông tin đơn hàng", err);
      } finally {
        setLoading(false);
      }
    };
    if (hash) fetchOrder();
  }, [hash]);

  if (loading) return <div className="min-h-screen flex items-center justify-center">Đang tải thông tin đơn hàng...</div>;

  return (
    <div className="min-h-screen bg-gray-50 p-6 flex flex-col items-center justify-center font-sans">
      <div className="max-w-md w-full bg-white shadow-lg rounded-2xl p-8 text-center border-t-4 border-green-500">
        <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg className="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M5 13l4 4L19 7"></path></svg>
        </div>
        
        <h1 className="text-2xl font-bold text-gray-900 mb-2">Đặt hàng thành công!</h1>
        <p className="text-gray-500 mb-6">Cảm ơn bạn đã mua sắm tại Lica.vn</p>

        <div className="bg-gray-50 rounded-xl p-4 text-left space-y-3 mb-6">
          <div className="flex justify-between">
            <span className="text-gray-500">Mã đơn hàng:</span>
            <span className="font-mono font-bold text-gray-800">{order?.code || "..."}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-500">Khách hàng:</span>
            <span className="font-medium text-gray-800">{order?.customer_name || "..."}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-gray-500">Phương thức:</span>
            <span className="font-medium text-gray-800">
              {order?.payment_method === 'cash_on_delivery' ? 'Thanh toán khi nhận (COD)' : 'Chuyển khoản'}
            </span>
          </div>
          <div className="border-t pt-2 flex justify-between font-bold text-lg text-red-600">
            <span>Tổng tiền:</span>
            <span>{new Intl.NumberFormat('vi-VN').format(Number(order?.total_amount || totalParam || 0))}đ</span>
          </div>
        </div>

        <div className="flex gap-3 justify-center">
          <Link href="/" className="px-6 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 font-medium">
            Về trang chủ
          </Link>
          <button onClick={() => window.print()} className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-medium">
            In đơn hàng
          </button>
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

echo "✅ Đã cài đặt xong luồng đặt hàng User!"
echo "👉 Truy cập thử: https://lica.vn/order/shipping"
