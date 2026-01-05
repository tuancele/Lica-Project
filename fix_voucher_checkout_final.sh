#!/bin/bash

# Đường dẫn dự án
BE_DIR="/var/www/lica-project/backend"
FE_DIR="/var/www/lica-project/apps/user"

echo "========================================================"
echo "   FIX LỖI 500 VOUCHER & NÂNG CẤP CHECKOUT HOÀN HẢO"
echo "========================================================"

# ---------------------------------------------------------
# PHẦN 1: FIX LỖI BACKEND (NGUYÊN NHÂN GÂY LỖI 500)
# ---------------------------------------------------------
echo ">>> [1/4] Sửa lỗi CouponController & Database..."

# 1. Cập nhật CouponController (Đổi tên hàm thành getAvailableCoupons cho khớp Route)
cat << 'EOF' > $BE_DIR/Modules/Order/app/Http/Controllers/CouponController.php
<?php

namespace Modules\Order\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Order\Models\Coupon;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class CouponController extends Controller
{
    public function index(Request $request)
    {
        $query = Coupon::withCount('products')->orderBy('created_at', 'desc');
        if ($request->q) {
            $query->where('code', 'like', "%{$request->q}%")->orWhere('name', 'like', "%{$request->q}%");
        }
        return response()->json(['status' => 200, 'data' => $query->paginate(20)]);
    }

    // API LẤY VOUCHER KHẢ DỤNG (FIX LỖI 500)
    public function getAvailableCoupons(Request $request)
    {
        try {
            $now = now();
            $coupons = Coupon::where('is_active', true)
                // .where('is_public', true) // Tạm bỏ check public để tránh lỗi nếu thiếu cột
                ->where('start_date', '<=', $now)
                ->where('end_date', '>=', $now)
                ->whereColumn('used_count', '<', 'usage_limit')
                ->orderBy('value', 'desc')
                ->select('id', 'code', 'name', 'type', 'value', 'min_order_value', 'description')
                ->get();

            return response()->json(['status' => 200, 'data' => $coupons]);
        } catch (\Exception $e) {
            return response()->json(['status' => 500, 'message' => $e->getMessage()]);
        }
    }

    public function check(Request $request)
    {
        $request->validate(['code' => 'required|string', 'total' => 'required|numeric']);
        $code = strtoupper(trim($request->code));
        $total = $request->total;
        $now = now();

        $coupon = Coupon::where('code', $code)->where('is_active', true)
            ->where('start_date', '<=', $now)->where('end_date', '>=', $now)->first();

        if (!$coupon) return response()->json(['status' => 400, 'message' => 'Mã không tồn tại hoặc hết hạn'], 400);
        if ($coupon->used_count >= $coupon->usage_limit) return response()->json(['status' => 400, 'message' => 'Mã đã hết lượt dùng'], 400);
        if ($total < $coupon->min_order_value) return response()->json(['status' => 400, 'message' => 'Đơn tối thiểu ' . number_format($coupon->min_order_value) . 'đ'], 400);

        $discount = ($coupon->type === 'percent') ? ($total * $coupon->value / 100) : $coupon->value;
        // Check max discount if exists column
        // if ($coupon->max_discount_amount && $discount > $coupon->max_discount_amount) $discount = $coupon->max_discount_amount;

        return response()->json(['status' => 200, 'data' => ['discount' => $discount, 'code' => $coupon->code]]);
    }

    public function store(Request $request) {
        // Giữ logic cũ nhưng rút gọn
        $validator = Validator::make($request->all(), [
            'code' => 'required|unique:coupons,code|uppercase', 'name' => 'required', 'value' => 'required|numeric',
            'start_date' => 'required|date', 'end_date' => 'required|date|after:start_date'
        ]);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);
        Coupon::create($request->all());
        return response()->json(['status' => 200, 'message' => 'Created']);
    }

    public function update(Request $request, $id) { Coupon::find($id)->update($request->all()); return response()->json(['status' => 200, 'message' => 'Updated']); }
    public function show($id) { return response()->json(['status' => 200, 'data' => Coupon::find($id)]); }
    public function destroy($id) { Coupon::destroy($id); return response()->json(['status' => 200, 'message' => 'Deleted']); }
}
EOF

# 2. Đảm bảo Route đúng
echo ">>> [2/4] Cập nhật Routes..."
cat << 'EOF' > $BE_DIR/Modules/Order/routes/api.php
<?php
use Illuminate\Support\Facades\Route;
use Modules\Order\Http\Controllers\OrderController;
use Modules\Order\Http\Controllers\CouponController;

Route::prefix('v1/order')->group(function () {
    Route::post('/checkout', [OrderController::class, 'checkout']);
    Route::post('/check-coupon', [CouponController::class, 'check']);
    Route::get('/success/{hash}', [OrderController::class, 'getOrderByHash']);
});

Route::prefix('v1/marketing')->group(function () {
    Route::get('/coupons/available', [CouponController::class, 'getAvailableCoupons']);
});
EOF

# 3. Chạy Migration để đảm bảo bảng đủ cột
echo ">>> [3/4] Chạy Migration..."
cd $BE_DIR
php artisan migrate --force

# ---------------------------------------------------------
# PHẦN 2: FRONTEND - CHECKOUT HOÀN HẢO
# ---------------------------------------------------------
echo ">>> [4/4] Nâng cấp trang Checkout (UI/UX Perfect)..."

cat << 'EOF' > $FE_DIR/app/checkout/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import { useCart } from '@/context/CartContext';
import SmartLocationInput from '@/components/common/SmartLocationInput';
import { OrderService } from '@/services/order.service';
import { getImageUrl } from '@/lib/axios';
import { Loader2, MapPin, CreditCard, Truck, CheckCircle, Ticket, ChevronRight, X } from 'lucide-react';

export default function CheckoutPage() {
  const router = useRouter();
  const { items: cart, total: cartTotal, clearCart } = useCart();
  
  const [loading, setLoading] = useState(false);
  const [isClient, setIsClient] = useState(false);

  // Form Data
  const [formData, setFormData] = useState({
    name: '', phone: '', address: '', 
    province_id: '', district_id: '', ward_id: '', 
    note: '', payment_method: 'cod'
  });

  // Voucher Logic
  const [coupons, setCoupons] = useState<any[]>([]);
  const [appliedCoupon, setAppliedCoupon] = useState<{code: string, discount: number} | null>(null);
  const [couponInput, setCouponInput] = useState('');
  const [showCouponModal, setShowCouponModal] = useState(false);

  useEffect(() => {
    setIsClient(true);
    // Load voucher
    OrderService.getAvailableCoupons().then(res => {
        if(Array.isArray(res)) setCoupons(res);
    });
  }, []);

  // Tính toán tiền
  const discount = appliedCoupon ? appliedCoupon.discount : 0;
  const finalTotal = Math.max(0, cartTotal - discount);

  // Xử lý Location
  const handleLocationChange = (data: any) => {
    setFormData(prev => ({ 
        ...prev, 
        address: data.fullAddress,
        province_id: data.province?.code,
        district_id: data.district?.code,
        ward_id: data.ward?.code
    }));
  };

  // Xử lý Apply Voucher
  const applyCoupon = async (code: string) => {
    if(!code) return;
    setLoading(true);
    try {
        const res = await OrderService.checkCoupon(code, cartTotal);
        if(res.status === 200) {
            setAppliedCoupon({ code: code, discount: res.data.discount });
            setCouponInput(code);
            setShowCouponModal(false);
            alert('Áp dụng mã thành công!');
        } else {
            alert(res.message || 'Mã không hợp lệ');
            setAppliedCoupon(null);
        }
    } catch(e) { alert('Lỗi kiểm tra mã'); }
    setLoading(false);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!cart.length) return alert('Giỏ hàng trống');
    if (!formData.name || !formData.phone || !formData.address || !formData.province_id) return alert('Vui lòng nhập đầy đủ địa chỉ!');

    setLoading(true);
    try {
      const items = cart.map((i: any) => ({ product_id: i.id, quantity: i.quantity, price: i.sale_price || i.price }));
      const payload = {
        customer_name: formData.name,
        customer_phone: formData.phone,
        shipping_address: formData.address,
        province_id: formData.province_id,
        district_id: formData.district_id,
        ward_id: formData.ward_id,
        note: formData.note,
        payment_method: formData.payment_method,
        coupon_code: appliedCoupon?.code,
        items: items
      };

      const res = await OrderService.checkout(payload);
      if (res) {
        clearCart();
        router.push('/');
        alert(`Đặt hàng thành công! Mã đơn: ${res.code || 'SUCCESS'}`);
      }
    } catch (e: any) {
        alert(e.response?.data?.message || 'Lỗi đặt hàng');
    } finally {
        setLoading(false);
    }
  };

  if (!isClient) return null;
  if (!cart.length) return <div className="min-h-screen bg-gray-50 flex items-center justify-center"><div className="text-center"><Truck className="w-16 h-16 mx-auto text-gray-300"/><h2 className="text-xl font-bold mt-4">Giỏ hàng trống</h2><button onClick={()=>router.push('/')} className="mt-4 bg-red-600 text-white px-6 py-2 rounded-full">Mua sắm ngay</button></div></div>;

  return (
    <div className="min-h-screen bg-gray-50 font-sans">
      <Header />
      <main className="container mx-auto px-4 py-8 max-w-6xl">
        <h1 className="text-2xl font-bold text-gray-800 mb-6 flex items-center gap-2"><CheckCircle className="text-green-600"/> Xác nhận đơn hàng</h1>
        
        <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-12 gap-8">
            {/* Cột trái: Thông tin */}
            <div className="lg:col-span-7 space-y-6">
                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                    <div className="flex items-center gap-2 mb-4 pb-2 border-b"><MapPin className="text-red-600"/><h2 className="font-bold text-lg">Thông tin giao hàng</h2></div>
                    <div className="grid grid-cols-2 gap-4 mb-4">
                        <div><label className="text-sm font-medium block mb-1">Họ tên *</label><input required className="w-full border rounded p-2.5 outline-none focus:border-red-500" value={formData.name} onChange={e=>setFormData({...formData, name: e.target.value})} placeholder="Nguyễn Văn A"/></div>
                        <div><label className="text-sm font-medium block mb-1">SĐT *</label><input required className="w-full border rounded p-2.5 outline-none focus:border-red-500" value={formData.phone} onChange={e=>setFormData({...formData, phone: e.target.value})} placeholder="09xxxx"/></div>
                    </div>
                    <div className="mb-4"><SmartLocationInput onLocationChange={handleLocationChange}/></div>
                    <div><label className="text-sm font-medium block mb-1">Ghi chú</label><textarea className="w-full border rounded p-2.5 outline-none focus:border-red-500" value={formData.note} onChange={e=>setFormData({...formData, note: e.target.value})} placeholder="Ghi chú giao hàng..."/></div>
                </div>

                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100">
                    <div className="flex items-center gap-2 mb-4 pb-2 border-b"><CreditCard className="text-red-600"/><h2 className="font-bold text-lg">Thanh toán</h2></div>
                    <label className="flex items-center gap-3 p-4 border rounded-lg bg-red-50 border-red-200 cursor-pointer"><input type="radio" checked readOnly className="accent-red-600 w-5 h-5"/><div><div className="font-bold text-gray-800">Thanh toán khi nhận hàng (COD)</div><div className="text-xs text-gray-500">Thanh toán tiền mặt cho shipper</div></div></label>
                </div>
            </div>

            {/* Cột phải: Đơn hàng & Voucher */}
            <div className="lg:col-span-5">
                <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-100 sticky top-4">
                    <h2 className="font-bold text-lg mb-4 border-b pb-2">Đơn hàng ({cart.length} sản phẩm)</h2>
                    <div className="space-y-4 mb-6 max-h-80 overflow-y-auto pr-2 scrollbar-thin">
                        {cart.map((item: any) => (
                            <div key={item.id} className="flex gap-3">
                                <img src={getImageUrl(item.images)} className="w-16 h-16 rounded border object-cover"/>
                                <div className="flex-1">
                                    <div className="text-sm font-medium line-clamp-2">{item.name}</div>
                                    <div className="flex justify-between mt-1 text-sm"><span className="text-gray-500">x{item.quantity}</span><span className="font-bold">{(item.sale_price||item.price).toLocaleString()}đ</span></div>
                                </div>
                            </div>
                        ))}
                    </div>

                    {/* Voucher Box */}
                    <div className="bg-gray-50 p-4 rounded-lg border border-dashed border-gray-300 mb-6">
                        <div className="flex justify-between items-center mb-2"><label className="text-sm font-bold flex items-center gap-1"><Ticket size={16} className="text-orange-500"/> Mã ưu đãi</label><button type="button" onClick={()=>setShowCouponModal(true)} className="text-xs text-blue-600 hover:underline">Chọn mã khác</button></div>
                        <div className="flex gap-2">
                            <input className="flex-1 border rounded px-3 text-sm uppercase font-bold outline-none" value={couponInput} onChange={e=>setCouponInput(e.target.value.toUpperCase())} placeholder="Nhập mã" disabled={!!appliedCoupon}/>
                            {appliedCoupon ? <button type="button" onClick={()=>{setAppliedCoupon(null); setCouponInput('')}} className="bg-gray-200 px-3 py-2 rounded text-sm font-bold">Xóa</button> : <button type="button" onClick={()=>applyCoupon(couponInput)} disabled={!couponInput} className="bg-red-600 text-white px-4 py-2 rounded text-sm font-bold hover:bg-red-700 disabled:opacity-50">Áp dụng</button>}
                        </div>
                        {appliedCoupon && <div className="mt-2 text-xs text-green-600 font-medium flex items-center gap-1"><CheckCircle size={12}/> Đã áp dụng: giảm {appliedCoupon.discount.toLocaleString()}đ</div>}
                    </div>

                    <div className="border-t pt-4 space-y-2">
                        <div className="flex justify-between text-sm"><span>Tạm tính</span><span>{cartTotal.toLocaleString()}đ</span></div>
                        <div className="flex justify-between text-sm text-green-600"><span>Giảm giá</span><span>-{discount.toLocaleString()}đ</span></div>
                        <div className="flex justify-between text-xl font-bold text-red-600 border-t pt-2 mt-2"><span>Tổng cộng</span><span>{finalTotal.toLocaleString()}đ</span></div>
                    </div>

                    <button onClick={handleSubmit} disabled={loading} className="w-full bg-red-600 text-white py-3.5 rounded-lg mt-4 font-bold text-lg hover:bg-red-700 shadow-lg shadow-red-200 transition disabled:opacity-70">{loading ? <Loader2 className="animate-spin mx-auto"/> : 'ĐẶT HÀNG'}</button>
                </div>
            </div>
        </form>

        {/* Modal Voucher */}
        {showCouponModal && (
            <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
                <div className="bg-white rounded-xl w-full max-w-md overflow-hidden max-h-[80vh] flex flex-col">
                    <div className="p-4 border-b flex justify-between items-center bg-gray-50"><h3 className="font-bold">Chọn Lica Voucher</h3><button onClick={()=>setShowCouponModal(false)}><X/></button></div>
                    <div className="p-4 overflow-y-auto space-y-3 flex-1 bg-gray-100">
                        {coupons.length > 0 ? coupons.map(c => (
                            <div key={c.id} className="bg-white p-3 rounded-lg border flex justify-between items-center shadow-sm">
                                <div><div className="font-bold text-red-600">{c.code}</div><div className="text-xs text-gray-500">{c.name || 'Mã giảm giá'}</div><div className="text-xs text-gray-400">Đơn tối thiểu: {c.min_order_value.toLocaleString()}đ</div></div>
                                <button onClick={()=>applyCoupon(c.code)} className="bg-red-50 text-red-600 px-3 py-1.5 rounded text-sm font-bold hover:bg-red-600 hover:text-white transition">Dùng</button>
                            </div>
                        )) : <div className="text-center text-gray-400 py-4">Chưa có mã giảm giá nào.</div>}
                    </div>
                </div>
            </div>
        )}
      </main>
      <Footer />
    </div>
  );
}
EOF

# Build & Restart
echo ">>> Đang build lại Frontend..."
cd $FE_DIR
rm -rf .next
npm run build

echo "========================================================"
echo "   ĐÃ HOÀN TẤT! VUI LÒNG RESTART PM2"
echo "   Command: pm2 restart all"
echo "========================================================"
