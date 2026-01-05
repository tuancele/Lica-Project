#!/bin/bash

# Đường dẫn
BE_DIR="/var/www/lica-project/backend"
FE_DIR="/var/www/lica-project/apps/user"

echo "========================================================"
echo "   NÂNG CẤP CHECKOUT: TÍCH HỢP VOUCHER & HOÀN THIỆN UI"
echo "========================================================"

# ---------------------------------------------------------
# PHẦN 1: BACKEND - API VOUCHER
# ---------------------------------------------------------
echo ">>> [1/5] Cập nhật Backend CouponController..."

# 1. Cập nhật CouponController (Thêm API lấy voucher khả dụng)
cat << 'EOF' > $BE_DIR/Modules/Order/app/Http/Controllers/CouponController.php
<?php

namespace Modules\Order\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Order\Models\Coupon;
use Illuminate\Support\Facades\Log;

class CouponController extends Controller
{
    // API: Lấy danh sách voucher đang hiệu lực
    public function getAvailableCoupons()
    {
        $now = now();
        $coupons = Coupon::where('is_active', true)
            ->where('start_at', '<=', $now)
            ->where('end_at', '>=', $now)
            ->where('usage_limit', '>', 0) // Còn lượt dùng
            ->orderBy('created_at', 'desc')
            ->get()
            ->map(function($c) {
                return [
                    'id' => $c->id,
                    'code' => $c->code,
                    'title' => $c->name ?? "Mã giảm giá",
                    'type' => $c->type, // 'fixed' or 'percent'
                    'value' => $c->value,
                    'min_order_value' => $c->min_order_value ?? 0,
                    'description' => $c->description
                ];
            });

        return response()->json(['status' => 200, 'data' => $coupons]);
    }

    // API: Kiểm tra mã voucher và trả về số tiền giảm
    public function check(Request $request)
    {
        $request->validate([
            'code' => 'required|string',
            'total' => 'required|numeric'
        ]);

        $code = strtoupper(trim($request->code));
        $total = $request->total;
        $now = now();

        $coupon = Coupon::where('code', $code)
            ->where('is_active', true)
            ->where('start_at', '<=', $now)
            ->where('end_at', '>=', $now)
            ->first();

        if (!$coupon) {
            return response()->json(['status' => 400, 'message' => 'Mã giảm giá không tồn tại hoặc đã hết hạn.'], 400);
        }

        if ($coupon->usage_limit <= 0) {
            return response()->json(['status' => 400, 'message' => 'Mã giảm giá đã hết lượt sử dụng.'], 400);
        }

        if ($total < $coupon->min_order_value) {
            return response()->json([
                'status' => 400, 
                'message' => 'Đơn hàng chưa đạt giá trị tối thiểu: ' . number_format($coupon->min_order_value) . 'đ'
            ], 400);
        }

        // Tính toán giảm giá
        $discount = 0;
        if ($coupon->type === 'percent') {
            $discount = $total * ($coupon->value / 100);
            if ($coupon->max_discount_amount && $discount > $coupon->max_discount_amount) {
                $discount = $coupon->max_discount_amount;
            }
        } else {
            $discount = $coupon->value;
        }

        return response()->json([
            'status' => 200,
            'data' => [
                'discount' => $discount,
                'code' => $coupon->code,
                'coupon_id' => $coupon->id
            ]
        ]);
    }
}
EOF

# 2. Đăng ký Route API
echo ">>> [2/5] Đăng ký Route Coupon..."
# Ghi đè file routes/api.php của module Order
cat << 'EOF' > $BE_DIR/Modules/Order/routes/api.php
<?php

use Illuminate\Support\Facades\Route;
use Modules\Order\Http\Controllers\OrderController;
use Modules\Order\Http\Controllers\CouponController;

Route::prefix('v1/order')->group(function () {
    Route::post('/checkout', [OrderController::class, 'checkout']);
    Route::get('/success/{hash}', [OrderController::class, 'getOrderByHash']);
    
    // Coupon Routes
    Route::post('/check-coupon', [CouponController::class, 'check']);
});

Route::prefix('v1/marketing')->group(function () {
    Route::get('/coupons/available', [CouponController::class, 'getAvailableCoupons']);
});
EOF

# ---------------------------------------------------------
# PHẦN 2: FRONTEND - SERVICE & PAGE
# ---------------------------------------------------------

# 3. Cập nhật Order Service
echo ">>> [3/5] Cập nhật Frontend OrderService..."
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
  items: Array<{ product_id: number; quantity: number; price: number; }>;
  coupon_code?: string;
  discount_amount?: number;
  note?: string;
}

export interface Coupon {
    id: number;
    code: string;
    title: string;
    type: 'fixed' | 'percent';
    value: number;
    min_order_value: number;
    description?: string;
}

export const OrderService = {
  checkout: async (payload: OrderPayload) => {
    const res = await api.post('/order/checkout', payload);
    return res.data;
  },
  
  // API lấy voucher khả dụng
  getAvailableCoupons: async () => {
    try {
        const res = await api.get('/marketing/coupons/available');
        return res.data.data || [];
    } catch { return []; }
  },

  // API kiểm tra voucher
  checkCoupon: async (code: string, total: number) => {
    const res = await api.post('/order/check-coupon', { code, total });
    return res.data; // Trả về { status: 200, data: { discount: ... } } hoặc lỗi
  },
  
  getOrderByHash: async (hash: string) => {
    const res = await api.get(`/order/success/${hash}`);
    return res.data.data || res.data;
  }
};
EOF

# 4. VIẾT LẠI TRANG CHECKOUT (Full tính năng)
echo ">>> [4/5] Rewrite Checkout Page (Perfect Version)..."
cat << 'EOF' > $FE_DIR/app/checkout/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import { useCart } from '@/context/CartContext';
import SmartLocationInput from '@/components/common/SmartLocationInput';
import { OrderService, OrderPayload, Coupon } from '@/services/order.service';
import { getImageUrl } from '@/lib/axios';
import { Loader2, MapPin, CreditCard, Truck, CheckCircle, Ticket, X, ChevronRight } from 'lucide-react';

export default function CheckoutPage() {
  const router = useRouter();
  const { items: cart, total: cartTotal, clearCart } = useCart();
  
  const [loading, setLoading] = useState(false);
  const [isClient, setIsClient] = useState(false);

  // Form State
  const [formData, setFormData] = useState({
    name: '', phone: '', address: '', province_id: '', district_id: '', ward_id: '', note: '', payment_method: 'cod'
  });

  // Voucher State
  const [couponCode, setCouponCode] = useState('');
  const [appliedCoupon, setAppliedCoupon] = useState<{code: string, discount: number} | null>(null);
  const [availableCoupons, setAvailableCoupons] = useState<Coupon[]>([]);
  const [checkingCoupon, setCheckingCoupon] = useState(false);
  const [showCouponList, setShowCouponList] = useState(false);

  useEffect(() => {
    setIsClient(true);
    // Load coupons available
    OrderService.getAvailableCoupons().then(setAvailableCoupons);
  }, []);

  // Tính toán tổng tiền cuối cùng
  const discountAmount = appliedCoupon ? appliedCoupon.discount : 0;
  const finalTotal = Math.max(0, cartTotal - discountAmount);

  // Xử lý địa chỉ
  const handleLocationChange = (data: any) => {
    setFormData(prev => ({ 
        ...prev, 
        address: data.fullAddress,
        province_id: data.province?.code || '',
        district_id: data.district?.code || '',
        ward_id: data.ward?.code || ''
    }));
  };

  // Xử lý áp dụng mã
  const handleApplyCoupon = async (codeToUse?: string) => {
    const code = codeToUse || couponCode;
    if (!code) return;

    setCheckingCoupon(true);
    try {
        const res = await OrderService.checkCoupon(code, cartTotal);
        if (res.status === 200) {
            setAppliedCoupon({ code: code, discount: res.data.discount });
            setCouponCode(code); // Update input text
            setShowCouponList(false); // Close list if open
            alert(`Áp dụng mã ${code} thành công! Giảm ${res.data.discount.toLocaleString()}đ`);
        } else {
            setAppliedCoupon(null);
            alert(res.message || 'Mã giảm giá không hợp lệ');
        }
    } catch (error: any) {
        setAppliedCoupon(null);
        alert(error?.response?.data?.message || 'Lỗi khi kiểm tra mã giảm giá');
    } finally {
        setCheckingCoupon(false);
    }
  };

  const removeCoupon = () => {
    setAppliedCoupon(null);
    setCouponCode('');
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!cart || cart.length === 0) return alert('Giỏ hàng trống!');
    if (!formData.name || !formData.phone || !formData.address || !formData.province_id) return alert('Vui lòng điền đầy đủ thông tin giao hàng!');

    setLoading(true);
    try {
      const items = cart.map((item: any) => ({
        product_id: item.id, quantity: item.quantity, price: item.sale_price || item.price
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
        items: items,
        coupon_code: appliedCoupon?.code,
        discount_amount: discountAmount
      };

      const res = await OrderService.checkout(payload);
      if (res) {
        clearCart();
        const orderCode = res.code || res.id || 'SUCCESS';
        alert('Đặt hàng thành công! Mã đơn: ' + orderCode);
        router.push('/');
      }
    } catch (error: any) {
      alert(error?.response?.data?.message || 'Lỗi kết nối server!');
    } finally {
      setLoading(false);
    }
  };

  if (!isClient) return null;
  if (!cart || cart.length === 0) return (
    <div className="min-h-screen flex flex-col bg-gray-50"><Header /><div className="flex-1 flex flex-col items-center justify-center p-10"><Truck className="w-16 h-16 text-gray-300 mb-4"/><h2 className="text-xl font-bold text-gray-600">Giỏ hàng trống</h2><button onClick={() => router.push('/')} className="mt-4 bg-red-600 text-white px-6 py-2 rounded-full">Mua sắm ngay</button></div><Footer /></div>
  );

  return (
    <div className="min-h-screen flex flex-col bg-gray-50">
      <Header />
      <main className="flex-1 container mx-auto px-4 py-8 max-w-6xl">
        <h1 className="text-2xl font-bold text-gray-800 mb-6 flex items-center gap-2"><CheckCircle className="text-green-600" /> Xác nhận đơn hàng</h1>

        <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-12 gap-8">
          {/* LEFT: INFO */}
          <div className="lg:col-span-7 space-y-6">
            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                <div className="flex items-center gap-2 mb-4 pb-2 border-b"><MapPin className="text-red-600" size={20} /><h2 className="font-bold text-lg text-gray-800">Thông tin giao hàng</h2></div>
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                    <div><label className="block text-sm font-medium mb-1">Họ tên</label><input required className="w-full border rounded p-2 outline-none focus:ring-1 focus:ring-red-500" value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} placeholder="Nguyễn Văn A" /></div>
                    <div><label className="block text-sm font-medium mb-1">Số điện thoại</label><input required className="w-full border rounded p-2 outline-none focus:ring-1 focus:ring-red-500" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} placeholder="0912xxxxxx" /></div>
                </div>
                <div className="mb-4"><SmartLocationInput onLocationChange={handleLocationChange} /></div>
                <div><label className="block text-sm font-medium mb-1">Ghi chú</label><textarea className="w-full border rounded p-2 h-20 outline-none" value={formData.note} onChange={e => setFormData({...formData, note: e.target.value})} placeholder="Ghi chú thêm..." /></div>
            </div>

            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                <div className="flex items-center gap-2 mb-4 pb-2 border-b"><CreditCard className="text-red-600" size={20} /><h2 className="font-bold text-lg text-gray-800">Thanh toán</h2></div>
                <label className="flex items-center gap-3 p-3 border rounded cursor-pointer bg-red-50 border-red-200"><input type="radio" checked readOnly className="accent-red-600 w-5 h-5" /><div><div className="font-medium">Thanh toán khi nhận hàng (COD)</div><div className="text-xs text-gray-500">Thanh toán tiền mặt cho shipper</div></div></label>
            </div>
          </div>

          {/* RIGHT: CART & VOUCHER */}
          <div className="lg:col-span-5">
            <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 sticky top-4">
                <h2 className="font-bold text-lg mb-4 border-b pb-2">Đơn hàng ({cart.length} sản phẩm)</h2>
                
                {/* List Items */}
                <div className="max-h-60 overflow-y-auto mb-4 space-y-3 pr-2 scrollbar-thin">
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

                {/* VOUCHER SECTION */}
                <div className="border-t pt-4 pb-4">
                    <div className="flex items-center justify-between mb-2">
                        <label className="text-sm font-bold flex items-center gap-1"><Ticket size={16} className="text-orange-500"/> Mã giảm giá</label>
                        <button type="button" onClick={() => setShowCouponList(!showCouponList)} className="text-xs text-blue-600 hover:underline">Chọn mã</button>
                    </div>
                    
                    {/* Input Voucher */}
                    <div className="flex gap-2">
                        <input type="text" className="flex-1 border rounded px-3 py-2 text-sm uppercase font-bold outline-none focus:border-red-500" 
                            placeholder="Nhập mã" 
                            value={couponCode} 
                            onChange={(e) => setCouponCode(e.target.value.toUpperCase())}
                            disabled={!!appliedCoupon}
                        />
                        {appliedCoupon ? (
                            <button type="button" onClick={removeCoupon} className="bg-gray-200 px-3 py-2 rounded text-sm font-bold hover:bg-gray-300">Xóa</button>
                        ) : (
                            <button type="button" onClick={() => handleApplyCoupon()} disabled={checkingCoupon || !couponCode} className="bg-red-600 text-white px-4 py-2 rounded text-sm font-bold hover:bg-red-700 disabled:opacity-50">
                                {checkingCoupon ? '...' : 'Áp dụng'}
                            </button>
                        )}
                    </div>

                    {/* Available Coupons List */}
                    {showCouponList && (
                        <div className="mt-3 space-y-2 bg-gray-50 p-2 rounded-lg border max-h-48 overflow-y-auto">
                            {availableCoupons.length > 0 ? availableCoupons.map(c => (
                                <div key={c.id} onClick={() => handleApplyCoupon(c.code)} className="bg-white p-2 border border-dashed rounded cursor-pointer hover:border-red-400 flex justify-between items-center group">
                                    <div>
                                        <div className="font-bold text-red-600 text-sm">{c.code}</div>
                                        <div className="text-xs text-gray-500">{c.title}</div>
                                    </div>
                                    <button className="text-xs bg-red-50 text-red-600 px-2 py-1 rounded group-hover:bg-red-600 group-hover:text-white transition">Dùng</button>
                                </div>
                            )) : <div className="text-xs text-center py-2 text-gray-400">Không có mã nào phù hợp</div>}
                        </div>
                    )}
                </div>

                {/* Summary */}
                <div className="border-t pt-4 space-y-2">
                    <div className="flex justify-between text-sm text-gray-600"><span>Tạm tính:</span><span>{cartTotal.toLocaleString()} ₫</span></div>
                    {appliedCoupon && (
                        <div className="flex justify-between text-sm text-green-600 font-medium">
                            <span>Giảm giá ({appliedCoupon.code}):</span>
                            <span>-{discountAmount.toLocaleString()} ₫</span>
                        </div>
                    )}
                    <div className="flex justify-between font-bold text-xl text-red-600 border-t border-dashed pt-2 mt-2">
                        <span>Tổng cộng:</span>
                        <span>{finalTotal.toLocaleString()} ₫</span>
                    </div>
                </div>

                <button type="submit" disabled={loading} className="w-full bg-red-600 text-white py-3.5 rounded-lg mt-4 font-bold hover:bg-red-700 disabled:opacity-70 shadow-lg shadow-red-200">
                    {loading ? <Loader2 className="animate-spin mx-auto"/> : 'ĐẶT HÀNG NGAY'}
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

# 5. Build & Clean
echo ">>> [5/5] Rebuild Frontend..."
cd $FE_DIR
rm -rf .next
npm run build

echo "========================================================"
echo "   HOÀN TẤT! VUI LÒNG CHẠY 'pm2 restart all'"
echo "========================================================"
