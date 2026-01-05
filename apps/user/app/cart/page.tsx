'use client';

import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import Navigation from '@/components/layout/Navigation';
import { useCart } from '@/context/CartContext';
import { getImageUrl } from '@/lib/axios';
import { Trash2 } from 'lucide-react';
import Link from 'next/link';

export default function CartPage() {
  const { items, removeFromCart, total } = useCart();

  return (
    <div className="bg-gray-50 min-h-screen font-sans">
      <Header />
      <Navigation />
      
      <div className="container-custom py-8">
        <h1 className="text-2xl font-bold mb-6 text-gray-800 uppercase">Giỏ hàng của bạn</h1>
        
        {items.length === 0 ? (
            <div className="text-center py-10 bg-white rounded-lg shadow-sm">
                <p className="text-gray-500 mb-4">Giỏ hàng đang trống</p>
                <Link href="/" className="text-lica-primary hover:underline">Tiếp tục mua sắm</Link>
            </div>
        ) : (
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <div className="lg:col-span-2">
                    <div className="bg-white rounded-lg shadow-sm overflow-hidden">
                        {items.map((item) => {
                            let img = null;
                            try { 
                                img = Array.isArray(item.images) ? item.images[0] : JSON.parse(item.images as string)[0]; 
                            } catch { img = item.images; }
                            
                            return (
                                <div key={item.id} className="p-4 border-b border-gray-100 flex gap-4 last:border-0">
                                    <img src={getImageUrl(img)} className="w-20 h-20 object-cover rounded border" />
                                    <div className="flex-1">
                                        <h3 className="font-medium text-gray-800 line-clamp-2 mb-1">{item.name}</h3>
                                        <div className="text-sm text-gray-500 mb-2">SKU: {item.sku}</div>
                                        <div className="flex justify-between items-center">
                                            <span className="font-bold text-lica-red">
                                                {(item.sale_price || item.price).toLocaleString('vi-VN')} ₫
                                            </span>
                                            <div className="flex items-center gap-4">
                                                <span className="text-sm">x {item.quantity}</span>
                                                <button onClick={() => removeFromCart(item.id)} className="text-gray-400 hover:text-red-500">
                                                    <Trash2 className="w-4 h-4" />
                                                </button>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            );
                        })}
                    </div>
                </div>
                
                <div className="lg:col-span-1">
                    <div className="bg-white rounded-lg shadow-sm p-6 sticky top-24">
                        <div className="flex justify-between mb-4 text-gray-600">
                            <span>Tạm tính:</span>
                            <span className="font-bold">{total.toLocaleString('vi-VN')} ₫</span>
                        </div>
                        <div className="border-t border-gray-100 pt-4 mb-6">
                            <div className="flex justify-between items-end">
                                <span className="font-bold text-gray-800">Tổng cộng:</span>
                                <span className="text-2xl font-bold text-lica-red">{total.toLocaleString('vi-VN')} ₫</span>
                            </div>
                            <p className="text-right text-xs text-gray-500 mt-1">(Đã bao gồm VAT)</p>
                        </div>
                        <Link href="/checkout" className="block w-full bg-lica-red text-white text-center font-bold py-3 rounded-lg hover:bg-red-700 transition-colors uppercase">
                            Tiến hành đặt hàng
                        </Link>
                    </div>
                </div>
            </div>
        )}
      </div>
      <Footer />
    </div>
  );
}
