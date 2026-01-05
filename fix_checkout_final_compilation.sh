#!/bin/bash

FE_ROOT="/var/www/lica-project/apps/user"

echo "========================================================"
echo "   FIX FINAL: CHECKOUT PAGE & ORDER SERVICE MATCHING"
echo "========================================================"

# 1. Cập nhật checkout/page.tsx
cat << 'EOF' > $FE_ROOT/app/checkout/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import { useCart } from '@/context/CartContext';
import SmartLocationInput from '@/components/common/SmartLocationInput';
import { OrderService, OrderPayload } from '@/services/order.service';
import { getImageUrl } from '@/lib/axios';
import { Loader2, MapPin, CreditCard, Truck, CheckCircle } from 'lucide-react';

export default function CheckoutPage() {
  const router = useRouter();
  const { items: cart, total, clearCart } = useCart();
  
  const [loading, setLoading] = useState(false);
  const [isClient, setIsClient] = useState(false);

  // State form mở rộng để lưu ID địa chính
  const [formData, setFormData] = useState({
    name: '',
    phone: '',
    address: '',
    province_id: '',
    district_id: '',
    ward_id: '',
    note: '',
    payment_method: 'cod'
  });

  useEffect(() => setIsClient(true), []);

  const handleLocationChange = (data: any) => {
    // data trả về: { province, district, ward, fullAddress }
    setFormData(prev => ({ 
        ...prev, 
        address: data.fullAddress,
        province_id: data.province?.code || '',
        district_id: data.district?.code || '',
        ward_id: data.ward?.code || ''
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (cart.length === 0) {
        alert('Giỏ hàng trống!');
        return;
    }
    
    if (!formData.address || !formData.province_id || !formData.district_id || !formData.ward_id) {
        alert('Vui lòng chọn đầy đủ địa chỉ (Tỉnh, Huyện, Xã)!');
        return;
    }

    setLoading(true);
    try {
      const items = cart.map((item: any) => ({
        product_id: item.id,
        quantity: item.quantity,
        price: item.sale_price || item.price
      }));

      // Payload chuẩn theo interface OrderPayload
      const payload: OrderPayload = {
        customer_name: formData.name,
        customer_phone: formData.phone,
        shipping_address: formData.address,
        province_id: formData.province_id,
        district_id: formData.district_id,
        ward_id: formData.ward_id,
        note: formData.note,
        payment_method: formData.payment_method,
        items: items
      };

      // FIX: Gọi đúng hàm checkout thay vì createOrder
      const res = await OrderService.checkout(payload);
      
      if (res) {
        clearCart();
        const orderCode = res.code || res.id || 'SUCCESS';
        alert('Đặt hàng thành công! Mã đơn hàng: ' + orderCode);
        router.push('/');
      } else {
        alert('Có lỗi xảy ra khi tạo đơn hàng.');
      }
    } catch (error: any) {
      console.error(error);
      const msg = error.response?.data?.message || 'Lỗi kết nối đến server.';
      alert(msg);
    } finally {
      setLoading(false);
    }
  };

  if (!isClient) return null;

  if (cart.length === 0) {
    return (
      <div className="min-h-screen flex flex-col">
        <Header />
        <div className="flex-1 flex flex-col items-center justify-center p-10 bg-gray-50">
            <div className="w-20 h-20 bg-gray-200 rounded-full flex items-center justify-center mb-4">
                <Truck className="w-10 h-10 text-gray-400" />
            </div>
            <h2 className="text-xl font-bold text-gray-800 mb-2">Giỏ hàng của bạn đang trống</h2>
            <p className="text-gray-500 mb-6">Hãy chọn thêm sản phẩm để tiến hành thanh toán nhé.</p>
            <button onClick={() => router.push('/')} className="bg-lica-primary text-white px-6 py-2 rounded-full hover:bg-red-700 transition">
                Tiếp tục mua sắm
            </button>
        </div>
        <Footer />
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col bg-gray-50">
      <Header />
      
      <main className="flex-1 container mx-auto px-4 py-8 max-w-6xl">
        <h1 className="text-2xl font-bold text-gray-800 mb-6 flex items-center gap-2">
            <CheckCircle className="text-green-600" /> Xác nhận đơn hàng
        </h1>

        <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          
          <div className="lg:col-span-7 space-y-6">
            
            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                <div className="flex items-center gap-2 mb-4 pb-2 border-b">
                    <MapPin className="text-lica-primary" size={20} />
                    <h2 className="font-bold text-lg text-gray-800">Thông tin giao hàng</h2>
                </div>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Họ và tên</label>
                        <input required type="text" className="w-full border border-gray-300 rounded-md px-3 py-2 focus:ring-2 focus:ring-red-200 outline-none" 
                            placeholder="Nguyễn Văn A"
                            value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})}
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Số điện thoại</label>
                        <input required type="tel" className="w-full border border-gray-300 rounded-md px-3 py-2 focus:ring-2 focus:ring-red-200 outline-none" 
                            placeholder="0912xxxxxx"
                            value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})}
                        />
                    </div>
                </div>

                <div className="mb-4">
                    <SmartLocationInput onLocationChange={handleLocationChange} />
                </div>

                <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Ghi chú đơn hàng (Tùy chọn)</label>
                    <textarea className="w-full border border-gray-300 rounded-md px-3 py-2 focus:ring-2 focus:ring-red-200 outline-none h-20"
                        placeholder="Ví dụ: Giao hàng giờ hành chính..."
                        value={formData.note} onChange={e => setFormData({...formData, note: e.target.value})}
                    ></textarea>
                </div>
            </div>

            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                <div className="flex items-center gap-2 mb-4 pb-2 border-b">
                    <CreditCard className="text-lica-primary" size={20} />
                    <h2 className="font-bold text-lg text-gray-800">Phương thức thanh toán</h2>
                </div>
                
                <div className="space-y-3">
                    <label className="flex items-center gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50 transition border-gray-200 has-[:checked]:border-red-500 has-[:checked]:bg-red-50">
                        <input type="radio" name="payment" value="cod" 
                            checked={formData.payment_method === 'cod'} 
                            onChange={() => setFormData({...formData, payment_method: 'cod'})}
                            className="w-5 h-5 accent-red-600"
                        />
                        <div className="flex-1">
                            <div className="font-medium text-gray-800">Thanh toán khi nhận hàng (COD)</div>
                            <div className="text-xs text-gray-500">Bạn sẽ thanh toán tiền mặt cho shipper khi nhận được hàng.</div>
                        </div>
                    </label>

                    <label className="flex items-center gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50 transition border-gray-200 has-[:checked]:border-red-500 has-[:checked]:bg-red-50">
                        <input type="radio" name="payment" value="banking" 
                            checked={formData.payment_method === 'banking'} 
                            onChange={() => setFormData({...formData, payment_method: 'banking'})}
                            className="w-5 h-5 accent-red-600"
                        />
                        <div className="flex-1">
                            <div className="font-medium text-gray-800">Chuyển khoản ngân hàng</div>
                            <div className="text-xs text-gray-500">Quét mã QR VietQR để thanh toán nhanh chóng.</div>
                        </div>
                    </label>
                </div>
            </div>

          </div>

          <div className="lg:col-span-5">
            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 sticky top-4">
                <h2 className="font-bold text-lg text-gray-800 mb-4 pb-2 border-b">Đơn hàng của bạn ({cart.length} sản phẩm)</h2>
                
                <div className="max-h-[400px] overflow-y-auto pr-2 space-y-4 mb-6 scrollbar-thin">
                    {cart.map((item: any) => {
                        const imgUrl = getImageUrl(item.images);
                        return (
                            <div key={item.id} className="flex gap-3">
                                <div className="w-16 h-16 border rounded bg-gray-50 shrink-0 overflow-hidden">
                                    <img src={imgUrl} className="w-full h-full object-cover" alt="" />
                                </div>
                                <div className="flex-1 min-w-0">
                                    <h3 className="text-sm font-medium text-gray-800 line-clamp-2">{item.name}</h3>
                                    <div className="flex justify-between items-center mt-1">
                                        <div className="text-xs text-gray-500">SL: {item.quantity}</div>
                                        <div className="text-sm font-bold text-gray-900">
                                            {(item.sale_price || item.price).toLocaleString('vi-VN')} ₫
                                        </div>
                                    </div>
                                </div>
                            </div>
                        );
                    })}
                </div>

                <div className="border-t pt-4 space-y-2 mb-6">
                    <div className="flex justify-between text-sm text-gray-600">
                        <span>Tạm tính</span>
                        <span>{total.toLocaleString('vi-VN')} ₫</span>
                    </div>
                    <div className="flex justify-between text-sm text-gray-600">
                        <span>Phí vận chuyển</span>
                        <span className="text-green-600 font-medium">Miễn phí</span>
                    </div>
                    <div className="flex justify-between text-lg font-bold text-red-600 border-t border-dashed pt-2 mt-2">
                        <span>Tổng cộng</span>
                        <span>{total.toLocaleString('vi-VN')} ₫</span>
                    </div>
                </div>

                <button type="submit" disabled={loading} className="w-full bg-lica-primary text-white py-3 rounded-lg font-bold text-lg hover:bg-red-700 transition flex items-center justify-center gap-2 disabled:opacity-70 disabled:cursor-not-allowed">
                    {loading ? <Loader2 className="animate-spin" /> : 'ĐẶT HÀNG NGAY'}
                </button>
                <p className="text-center text-xs text-gray-400 mt-3">
                    Bằng việc đặt hàng, bạn đồng ý với điều khoản sử dụng của Lica.vn
                </p>
            </div>
          </div>

        </form>
      </main>
      <Footer />
    </div>
  );
}
EOF

# Build lại
echo ">>> Rebuilding Frontend..."
cd $FE_ROOT
npm run build

echo "========================================================"
echo "   ĐÃ SỬA XONG! VUI LÒNG RESTART PM2."
echo "========================================================"
