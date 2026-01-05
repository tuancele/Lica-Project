#!/bin/bash

FE_DIR="/var/www/lica-project/apps/user"

echo "========================================================"
echo "   SỬA LỖI CHECKOUT FRONTEND (CLEAN BUILD)"
echo "========================================================"

# 1. Cập nhật Order Service (Đảm bảo interface và method checkout đúng)
echo ">>> [1/4] Cập nhật Order Service..."
cat << 'EOF' > $FE_DIR/services/order.service.ts
import api from '@/lib/axios';

export interface OrderPayload {
  customer_name: string;
  customer_phone: string;
  customer_email?: string;
  shipping_address: string;
  province_id: string | number;
  district_id: string | number;
  ward_id: string | number;
  payment_method: string;
  items: Array<{
    product_id: number;
    quantity: number;
    price: number;
  }>;
  coupon_code?: string;
  note?: string;
}

export const OrderService = {
  // Method checkout chính thức
  checkout: async (payload: OrderPayload) => {
    const res = await api.post('/order/checkout', payload);
    return res.data;
  },
  
  checkCoupon: async (code: string, total: number) => {
    const res = await api.post('/order/check-coupon', { code, total });
    return res.data;
  },
  
  getOrderByHash: async (hash: string) => {
    const res = await api.get(`/order/success/${hash}`);
    return res.data.data || res.data;
  }
};
EOF

# 2. Cập nhật Checkout Page (Gọi đúng method checkout)
echo ">>> [2/4] Cập nhật Checkout Page..."
rm -f $FE_DIR/app/checkout/page.tsx # Xóa file cũ để đảm bảo ghi mới
cat << 'EOF' > $FE_DIR/app/checkout/page.tsx
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
  // Lấy items và alias thành cart để đúng logic
  const { items: cart, total, clearCart } = useCart();
  
  const [loading, setLoading] = useState(false);
  const [isClient, setIsClient] = useState(false);

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
    
    if (!cart || cart.length === 0) {
        alert('Giỏ hàng trống!');
        return;
    }
    
    // Validate dữ liệu
    if (!formData.name || !formData.phone || !formData.address || !formData.province_id) {
        alert('Vui lòng điền đầy đủ thông tin giao hàng!');
        return;
    }

    setLoading(true);
    try {
      const items = cart.map((item: any) => ({
        product_id: item.id,
        quantity: item.quantity,
        price: item.sale_price || item.price
      }));

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

      // Gọi API checkout (đã sửa tên hàm cho khớp service)
      const res = await OrderService.checkout(payload);
      
      if (res) {
        clearCart();
        const orderCode = res.code || res.id || 'SUCCESS';
        alert('Đặt hàng thành công! Mã đơn: ' + orderCode);
        router.push('/');
      } else {
        alert('Có lỗi xảy ra, vui lòng thử lại.');
      }
    } catch (error: any) {
      console.error(error);
      const msg = error?.response?.data?.message || 'Lỗi kết nối server!';
      alert(msg);
    } finally {
      setLoading(false);
    }
  };

  if (!isClient) return null;

  if (!cart || cart.length === 0) {
    return (
      <div className="min-h-screen flex flex-col bg-gray-50">
        <Header />
        <div className="flex-1 flex flex-col items-center justify-center p-10">
            <div className="w-20 h-20 bg-gray-200 rounded-full flex items-center justify-center mb-4">
                <Truck className="w-10 h-10 text-gray-400" />
            </div>
            <h2 className="text-xl font-bold text-gray-800 mb-2">Giỏ hàng trống</h2>
            <button onClick={() => router.push('/')} className="mt-4 bg-red-600 text-white px-6 py-2 rounded-full hover:bg-red-700">
                Mua sắm ngay
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
          {/* Form thông tin bên trái */}
          <div className="lg:col-span-7 space-y-6">
            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                <div className="flex items-center gap-2 mb-4 pb-2 border-b">
                    <MapPin className="text-red-600" size={20} />
                    <h2 className="font-bold text-lg text-gray-800">Thông tin giao hàng</h2>
                </div>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div>
                        <label className="block text-sm font-medium mb-1">Họ tên</label>
                        <input required className="w-full border rounded p-2 outline-none focus:ring-1 focus:ring-red-500" 
                            placeholder="Nhập họ tên"
                            value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} />
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-1">Số điện thoại</label>
                        <input required className="w-full border rounded p-2 outline-none focus:ring-1 focus:ring-red-500" 
                            placeholder="Nhập SĐT"
                            value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} />
                    </div>
                </div>
                
                {/* Component chọn địa chỉ thông minh */}
                <div className="mb-4">
                    <SmartLocationInput onLocationChange={handleLocationChange} />
                </div>

                <div>
                    <label className="block text-sm font-medium mb-1">Ghi chú</label>
                    <textarea className="w-full border rounded p-2 h-20 outline-none focus:ring-1 focus:ring-red-500"
                        placeholder="Ghi chú giao hàng..."
                        value={formData.note} onChange={e => setFormData({...formData, note: e.target.value})} />
                </div>
            </div>

            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                <div className="flex items-center gap-2 mb-4 pb-2 border-b">
                    <CreditCard className="text-red-600" size={20} />
                    <h2 className="font-bold text-lg text-gray-800">Thanh toán</h2>
                </div>
                <div className="space-y-3">
                    <label className="flex items-center gap-3 p-3 border rounded cursor-pointer hover:bg-gray-50">
                        <input type="radio" checked readOnly className="accent-red-600 w-5 h-5" />
                        <div>
                            <div className="font-medium">Thanh toán khi nhận hàng (COD)</div>
                            <div className="text-xs text-gray-500">Thanh toán tiền mặt cho shipper</div>
                        </div>
                    </label>
                </div>
            </div>
          </div>

          {/* Tóm tắt đơn hàng bên phải */}
          <div className="lg:col-span-5">
            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 sticky top-4">
                <h2 className="font-bold text-lg mb-4 border-b pb-2">Đơn hàng ({cart.length} sản phẩm)</h2>
                <div className="max-h-80 overflow-y-auto mb-4 space-y-3">
                    {cart.map((item: any) => (
                        <div key={item.id} className="flex gap-3">
                            <img src={getImageUrl(item.images)} className="w-14 h-14 object-cover rounded border" />
                            <div className="flex-1">
                                <div className="text-sm font-medium line-clamp-1">{item.name}</div>
                                <div className="text-xs text-gray-500">x{item.quantity}</div>
                                <div className="text-sm font-bold text-red-600">{(item.sale_price || item.price).toLocaleString()} ₫</div>
                            </div>
                        </div>
                    ))}
                </div>
                <div className="border-t pt-4">
                    <div className="flex justify-between font-bold text-xl text-red-600">
                        <span>Tổng cộng:</span>
                        <span>{total.toLocaleString()} ₫</span>
                    </div>
                </div>
                <button type="submit" disabled={loading} className="w-full bg-red-600 text-white py-3 rounded-lg mt-4 font-bold hover:bg-red-700 disabled:opacity-70">
                    {loading ? 'Đang xử lý...' : 'ĐẶT HÀNG NGAY'}
                </button>
            </div>
          </div>
        </form>
      </main>
      <Footer />
    </div>
  );
}
EOF

# 3. Xóa cache và Build lại
echo ">>> [3/4] Xóa cache build (.next)..."
cd $FE_DIR
rm -rf .next

echo ">>> [4/4] Bắt đầu build lại (Clean Build)..."
npm run build

echo "========================================================"
echo "   NẾU THẤY 'Compiled successfully', HÃY RESTART PM2"
echo "   Command: pm2 restart all"
echo "========================================================"
