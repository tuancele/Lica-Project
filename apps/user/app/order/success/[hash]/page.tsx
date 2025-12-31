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
