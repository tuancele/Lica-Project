'use client';

import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import { CheckCircle } from 'lucide-react';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import { OrderService } from '@/services/order.service';

export default function OrderSuccess() {
  const { hash } = useParams();
  const [order, setOrder] = useState<any>(null);

  useEffect(() => {
    if (hash) {
        OrderService.getOrderByHash(hash as string).then(setOrder);
    }
  }, [hash]);

  return (
    <div className="bg-gray-50 min-h-screen font-sans">
      <Header />
      <div className="container-custom py-12">
        <div className="max-w-2xl mx-auto bg-white p-8 rounded-xl shadow-sm text-center">
            <div className="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-6">
                <CheckCircle className="w-10 h-10 text-green-600" />
            </div>
            
            <h1 className="text-2xl font-bold text-gray-800 mb-2">Đặt hàng thành công!</h1>
            <p className="text-gray-500 mb-8">Cảm ơn bạn đã mua sắm tại Lica.vn. Mã đơn hàng của bạn là:</p>
            
            {order ? (
                <div className="bg-gray-50 p-6 rounded-lg mb-8 text-left">
                    <div className="flex justify-between mb-2 pb-2 border-b border-gray-200">
                        <span className="text-gray-600">Mã đơn hàng:</span>
                        <span className="font-bold text-lica-primary text-lg">#{order.code}</span>
                    </div>
                    <div className="flex justify-between mb-2">
                        <span className="text-gray-600">Người nhận:</span>
                        <span className="font-medium">{order.customer_name}</span>
                    </div>
                    <div className="flex justify-between mb-2">
                        <span className="text-gray-600">Tổng tiền:</span>
                        <span className="font-bold text-lica-red">{Number(order.total_amount).toLocaleString('vi-VN')} ₫</span>
                    </div>
                    <div className="flex justify-between">
                        <span className="text-gray-600">Phương thức:</span>
                        <span className="font-medium uppercase">{order.payment_method}</span>
                    </div>
                </div>
            ) : (
                <div className="h-32 flex items-center justify-center text-gray-400">Đang tải thông tin đơn hàng...</div>
            )}
            
            <div className="flex gap-4 justify-center">
                <Link href="/" className="px-6 py-2 border border-gray-300 rounded hover:bg-gray-50 transition-colors">
                    Về trang chủ
                </Link>
                <Link href="/deals" className="px-6 py-2 bg-lica-primary text-white rounded hover:bg-opacity-90 transition-colors">
                    Tiếp tục mua sắm
                </Link>
            </div>
        </div>
      </div>
      <Footer />
    </div>
  );
}
