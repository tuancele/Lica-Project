#!/bin/bash

echo "🚀 Đang nâng cấp tính năng Gợi ý Voucher tại Checkout..."

cd /var/www/lica-project/backend

# ==============================================================================
# 1. BACKEND: API Lấy Voucher Khả dụng (Public & Active)
# ==============================================================================
echo "⚙️ Cập nhật CouponController..."

# Thêm hàm getAvailable vào Controller
cat << 'EOF' > Modules/Order/app/Http/Controllers/CouponController.php
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
    // ... Giữ nguyên các hàm index, store, update, show, destroy ...
    public function index(Request $request)
    {
        $query = Coupon::withCount('products')->orderBy('created_at', 'desc');
        if ($request->q) {
            $query->where('code', 'like', "%{$request->q}%")->orWhere('name', 'like', "%{$request->q}%");
        }
        return response()->json(['status' => 200, 'data' => $query->paginate(20)]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'code' => 'required|unique:coupons,code|uppercase',
            'name' => 'required',
            'value' => 'required|numeric|min:0',
            'start_date' => 'required|date',
            'end_date' => 'required|date|after:start_date',
        ]);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        DB::beginTransaction();
        try {
            $data = $request->except('product_ids');
            $data['apply_type'] = count($request->product_ids ?? []) > 0 ? 'specific' : 'all';
            $coupon = Coupon::create($data);
            if ($request->has('product_ids')) $coupon->products()->sync($request->product_ids);
            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Tạo thành công']);
        } catch (\Exception $e) { DB::rollBack(); return response()->json(['status' => 500, 'message' => $e->getMessage()], 500); }
    }

    public function update(Request $request, $id)
    {
        $coupon = Coupon::find($id);
        if (!$coupon) return response()->json(['message' => 'Not found'], 404);
        
        $validator = Validator::make($request->all(), [
            'code' => ['required', 'uppercase', Rule::unique('coupons')->ignore($coupon->id)],
            'name' => 'required',
            'value' => 'required|numeric|min:0',
        ]);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        DB::beginTransaction();
        try {
            $data = $request->except('product_ids');
            $data['apply_type'] = count($request->product_ids ?? []) > 0 ? 'specific' : 'all';
            $coupon->update($data);
            if ($request->has('product_ids')) $coupon->products()->sync($request->product_ids);
            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Cập nhật thành công']);
        } catch (\Exception $e) { DB::rollBack(); return response()->json(['status' => 500, 'message' => $e->getMessage()], 500); }
    }

    public function show($id) {
        $coupon = Coupon::with('products:id,name,thumbnail,sku')->find($id);
        if (!$coupon) return response()->json(['message' => 'Not found'], 404);
        $coupon->product_ids = $coupon->products->pluck('id');
        return response()->json(['status' => 200, 'data' => $coupon]);
    }
    
    public function destroy($id) { Coupon::destroy($id); return response()->json(['status' => 200, 'message' => 'Deleted']); }

    // --- NEW: API Lấy Voucher khả dụng cho Checkout ---
    public function getAvailable(Request $request)
    {
        $now = now();
        // Lấy các mã: Đang hoạt động + Công khai + Trong thời gian + Còn lượt dùng
        $coupons = Coupon::where('is_active', true)
            ->where('is_public', true)
            ->where('start_date', '<=', $now)
            ->where('end_date', '>=', $now)
            ->whereColumn('used_count', '<', 'usage_limit')
            ->orderBy('value', 'desc') // Ưu tiên giảm nhiều lên đầu
            ->get();

        return response()->json(['status' => 200, 'data' => $coupons]);
    }
}
EOF

# Thêm Route getAvailable
echo "🔗 Cập nhật Route..."
if ! grep -q "getAvailable" /var/www/lica-project/backend/Modules/Order/routes/api.php; then
    sed -i "/Route::get('\/', \[CouponController::class, 'index'\]);/a \    Route::get('/available', [CouponController::class, 'getAvailable']);" /var/www/lica-project/backend/Modules/Order/routes/api.php
fi

# ==============================================================================
# 2. FRONTEND: Cập nhật ShippingPage (Hiện list voucher)
# ==============================================================================
echo "💻 Cập nhật Frontend UI..."

cat << 'EOF' > /var/www/lica-project/apps/user/app/order/shipping/page.tsx
"use client";

import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { MapPin, Phone, User, Truck, Banknote, CreditCard, Loader2, Ticket, Check } from "lucide-react";
import SmartLocationInput from "@/components/common/SmartLocationInput";

export default function ShippingPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [initializing, setInitializing] = useState(true);
  const [error, setError] = useState("");

  const [formData, setFormData] = useState({
    customer_name: "", customer_phone: "", customer_email: "",
    payment_method: "cash_on_delivery", note: ""
  });
  const [addressData, setAddressData] = useState({ street: "", province_code: "", district_code: "", ward_code: "" });
  const [fullLocationLabel, setFullLocationLabel] = useState("");
  const [locationNames, setLocationNames] = useState({ province: "", district: "", ward: "" });

  // Coupon State
  const [couponCode, setCouponCode] = useState("");
  const [appliedCoupon, setAppliedCoupon] = useState<{code: string, discount: number} | null>(null);
  const [checkingCoupon, setCheckingCoupon] = useState(false);
  const [couponMsg, setCouponMsg] = useState("");
  
  // List voucher gợi ý
  const [availableCoupons, setAvailableCoupons] = useState<any[]>([]);

  const cartItems = [{ product_id: 1, quantity: 1, name: "Sản phẩm Demo", price: 500000 }];
  const subTotal = cartItems.reduce((acc, item) => acc + (item.price * item.quantity), 0);
  const totalAmount = subTotal - (appliedCoupon?.discount || 0);

  useEffect(() => {
    const initData = async () => {
      try {
        const token = localStorage.getItem("token");
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        
        // Load Coupons gợi ý
        try {
            const couponRes = await axios.get(`${apiUrl}/api/v1/marketing/coupons/available`);
            setAvailableCoupons(couponRes.data.data);
        } catch (e) {}

        if (token) {
            const [meRes, addrRes] = await Promise.all([
                axios.get(`${apiUrl}/api/v1/profile/me`, { headers: { Authorization: `Bearer ${token}` } }),
                axios.get(`${apiUrl}/api/v1/profile/addresses`, { headers: { Authorization: `Bearer ${token}` } })
            ]);
            const user = meRes.data.data;
            const addresses = addrRes.data.data;
            const defaultAddr = addresses.find((a: any) => a.is_default) || addresses[0];

            setFormData(prev => ({
                ...prev, customer_name: defaultAddr ? defaultAddr.name : user.name,
                customer_phone: defaultAddr ? defaultAddr.phone : (user.phone || ""), customer_email: user.email || ""
            }));

            if (defaultAddr && defaultAddr.province_id) {
                 setAddressData({ street: defaultAddr.address, province_code: defaultAddr.province_id, district_code: defaultAddr.district_id, ward_code: defaultAddr.ward_id });
                 try {
                     const [pRes, dRes, wRes] = await Promise.all([
                        axios.get(`${apiUrl}/api/v1/location/provinces`),
                        axios.get(`${apiUrl}/api/v1/location/districts/${defaultAddr.province_id}`),
                        axios.get(`${apiUrl}/api/v1/location/wards/${defaultAddr.district_id}`)
                     ]);
                     const pName = pRes.data.data.find((x:any)=>x.code==defaultAddr.province_id)?.name;
                     const dName = dRes.data.data.find((x:any)=>x.code==defaultAddr.district_id)?.name;
                     const wName = wRes.data.data.find((x:any)=>x.code==defaultAddr.ward_id)?.name;
                     setFullLocationLabel(`${wName}, ${dName}, ${pName}`);
                     setLocationNames({ province: pName, district: dName, ward: wName });
                 } catch(e) {}
            }
        }
      } catch (err) { console.log("Guest"); } finally { setInitializing(false); }
    };
    initData();
  }, []);

  const checkAndApply = async (code: string) => {
    setCheckingCoupon(true);
    setCouponMsg("");
    setCouponCode(code); // Update input UI
    try {
        const res = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/check-coupon`, {
            code: code,
            items: cartItems.map(i => ({ product_id: i.product_id, quantity: i.quantity }))
        });
        setAppliedCoupon({ code: code, discount: res.data.data.discount });
        setCouponMsg("Áp dụng mã thành công!");
    } catch (err: any) {
        setAppliedCoupon(null);
        setCouponMsg(err.response?.data?.message || "Mã không hợp lệ");
    } finally { setCheckingCoupon(false); }
  }

  const handleApplyCoupon = () => checkAndApply(couponCode);

  const handleRemoveCoupon = () => {
    setAppliedCoupon(null);
    setCouponCode("");
    setCouponMsg("");
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    if (!addressData.province_code || !addressData.street) { setError("Vui lòng nhập địa chỉ đầy đủ."); setLoading(false); return; }

    try {
      const finalAddress = `${addressData.street}, ${locationNames.ward}, ${locationNames.district}, ${locationNames.province}`;
      const token = localStorage.getItem("token");
      const headers = token ? { Authorization: `Bearer ${token}` } : {};
      
      const payload = {
        ...formData, shipping_address: finalAddress,
        coupon_code: appliedCoupon ? appliedCoupon.code : null,
        items: cartItems.map(i => ({ product_id: i.product_id, quantity: i.quantity }))
      };

      const res = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/checkout`, payload, { headers });
      if (res.data.status === 200) router.push(res.data.data.redirect_url);
    } catch (err: any) { setError(err.response?.data?.message || "Lỗi đặt hàng"); } finally { setLoading(false); }
  };

  if (initializing) return <div className="h-screen flex justify-center items-center"><Loader2 className="animate-spin text-blue-600"/></div>;

  return (
    <div className="min-h-screen bg-gray-50 p-4 font-sans">
      <div className="max-w-4xl mx-auto bg-white shadow rounded-xl overflow-hidden">
        <div className="bg-gradient-to-r from-blue-700 to-blue-600 p-4 text-white font-bold flex gap-2 items-center">
            <MapPin size={20}/> Thông tin giao hàng
        </div>
        <div className="p-6 grid md:grid-cols-3 gap-8">
            <form onSubmit={handleSubmit} className="md:col-span-2 space-y-6">
                <div className="grid grid-cols-2 gap-4">
                    <div>
                        <label className="text-sm font-medium mb-1 block">Họ tên *</label>
                        <div className="relative">
                            <User size={16} className="absolute left-3 top-3 text-gray-400"/>
                            <input className="w-full border rounded-lg pl-9 p-2.5 outline-none focus:ring-2 focus:ring-blue-500" value={formData.customer_name} onChange={e => setFormData({...formData, customer_name: e.target.value})} required />
                        </div>
                    </div>
                    <div>
                        <label className="text-sm font-medium mb-1 block">SĐT *</label>
                        <div className="relative">
                            <Phone size={16} className="absolute left-3 top-3 text-gray-400"/>
                            <input className="w-full border rounded-lg pl-9 p-2.5 outline-none focus:ring-2 focus:ring-blue-500" value={formData.customer_phone} onChange={e => setFormData({...formData, customer_phone: e.target.value})} required />
                        </div>
                    </div>
                </div>

                <div className="bg-blue-50/50 p-5 rounded-xl border border-blue-100">
                    <h3 className="text-sm font-bold uppercase mb-3 flex items-center gap-2 text-gray-800"><Truck size={16}/> Địa chỉ nhận hàng</h3>
                    <div className="mb-3">
                        <label className="text-xs font-medium text-gray-500 mb-1 block">Khu vực *</label>
                        <SmartLocationInput onSelect={(d) => { setAddressData(p=>({...p, province_code: d.province_code, district_code: d.district_code, ward_code: d.ward_code})); setFullLocationLabel(d.label); setLocationNames({province: d.province_name, district: d.district_name, ward: d.ward_name}); }} initialLabel={fullLocationLabel} />
                    </div>
                    <div>
                        <label className="text-xs font-medium text-gray-500 mb-1 block">Chi tiết *</label>
                        <input className="w-full border rounded-lg p-2.5 text-sm outline-none focus:ring-2 focus:ring-blue-500" placeholder="VD: Số 10, Ngõ 5..." value={addressData.street} onChange={e => setAddressData({...addressData, street: e.target.value})} required />
                    </div>
                </div>

                <div><label className="text-sm font-medium mb-1 block">Ghi chú</label><textarea className="w-full border rounded-lg p-3 text-sm outline-none focus:ring-2 focus:ring-blue-500" rows={2} value={formData.note} onChange={e => setFormData({...formData, note: e.target.value})}></textarea></div>

                <div>
                    <label className="text-sm font-medium mb-2 block">Thanh toán</label>
                    <div className="grid grid-cols-2 gap-3">
                        <label className={`border rounded-lg p-4 flex items-center gap-2 cursor-pointer transition ${formData.payment_method==='cash_on_delivery'?'border-blue-600 bg-blue-50 ring-1 ring-blue-600':'hover:bg-gray-50'}`}>
                            <input type="radio" name="pay" value="cash_on_delivery" checked={formData.payment_method==='cash_on_delivery'} onChange={e=>setFormData({...formData, payment_method: e.target.value})} className="accent-blue-600"/>
                            <Banknote size={20} className="text-green-600"/>
                            <span className="text-sm font-medium">COD</span>
                        </label>
                        <label className={`border rounded-lg p-4 flex items-center gap-2 cursor-pointer transition ${formData.payment_method==='banking'?'border-blue-600 bg-blue-50 ring-1 ring-blue-600':'hover:bg-gray-50'}`}>
                            <input type="radio" name="pay" value="banking" checked={formData.payment_method==='banking'} onChange={e=>setFormData({...formData, payment_method: e.target.value})} className="accent-blue-600"/>
                            <CreditCard size={20} className="text-blue-600"/>
                            <span className="text-sm font-medium">Chuyển khoản</span>
                        </label>
                    </div>
                </div>
                
                {error && <div className="bg-red-50 text-red-600 p-3 rounded text-sm border border-red-200">{error}</div>}
                <button type="submit" disabled={loading} className="w-full bg-red-600 text-white font-bold py-4 rounded-lg hover:bg-red-700 shadow-lg shadow-red-200 uppercase transition">
                    {loading ? "Đang xử lý..." : `ĐẶT HÀNG NGAY (${new Intl.NumberFormat('vi-VN').format(totalAmount)}đ)`}
                </button>
            </form>

            <div className="h-fit space-y-4">
                <div className="bg-gray-50 p-5 rounded-xl border border-gray-200">
                    <h2 className="font-bold border-b border-gray-300 pb-3 mb-4 text-sm uppercase text-gray-800">Đơn hàng</h2>
                    <div className="space-y-3 max-h-60 overflow-y-auto pr-1">
                        {cartItems.map((i, idx) => <div key={idx} className="flex justify-between text-sm"><span>{i.name} x{i.quantity}</span><span className="font-medium">{new Intl.NumberFormat('vi-VN').format(i.price * i.quantity)}đ</span></div>)}
                    </div>
                    
                    {/* COUPON SECTION */}
                    <div className="border-t border-dashed border-gray-300 pt-4 mt-4">
                        <label className="text-xs font-bold text-gray-500 uppercase mb-2 block flex items-center gap-1"><Ticket size={14}/> Mã giảm giá</label>
                        <div className="flex gap-2 mb-3">
                            <input type="text" placeholder="Nhập mã" className="flex-1 border rounded p-2 text-sm uppercase font-bold text-gray-700 outline-none focus:border-blue-500" 
                                value={couponCode} onChange={e => setCouponCode(e.target.value.toUpperCase())} disabled={!!appliedCoupon} />
                            {appliedCoupon ? (
                                <button type="button" onClick={handleRemoveCoupon} className="bg-gray-200 text-gray-600 px-3 py-2 rounded text-sm font-bold hover:bg-gray-300 transition">Xóa</button>
                            ) : (
                                <button type="button" onClick={handleApplyCoupon} disabled={checkingCoupon} className="bg-blue-600 text-white px-3 py-2 rounded text-sm font-bold hover:bg-blue-700 disabled:opacity-70 transition">Áp dụng</button>
                            )}
                        </div>
                        {couponMsg && <div className={`text-xs font-medium mb-3 ${appliedCoupon ? 'text-green-600' : 'text-red-600'}`}>{couponMsg}</div>}

                        {/* LIST AVAILABLE COUPONS */}
                        {!appliedCoupon && availableCoupons.length > 0 && (
                            <div className="space-y-2">
                                <p className="text-xs text-gray-400">Voucher dành cho bạn:</p>
                                {availableCoupons.filter(c => subTotal >= c.min_order_value).length > 0 ? (
                                    availableCoupons.filter(c => subTotal >= c.min_order_value).map(c => (
                                        <div key={c.id} onClick={() => checkAndApply(c.code)} 
                                            className="flex justify-between items-center p-2.5 bg-white border border-blue-200 border-dashed rounded-lg cursor-pointer hover:bg-blue-50 transition group relative overflow-hidden">
                                            <div className="w-1.5 h-full bg-blue-500 absolute left-0 top-0"></div>
                                            <div className="pl-3">
                                                <div className="text-sm font-bold text-blue-700">{c.code}</div>
                                                <div className="text-xs text-gray-500">Giảm {c.type === 'fixed' ? new Intl.NumberFormat('vi-VN').format(c.value) + 'đ' : c.value + '%'}</div>
                                            </div>
                                            <button className="text-xs bg-blue-600 text-white px-2 py-1 rounded font-bold group-hover:bg-blue-700">Dùng</button>
                                        </div>
                                    ))
                                ) : (
                                    <div className="text-xs text-gray-400 italic">Chưa có voucher phù hợp cho đơn hàng này.</div>
                                )}
                            </div>
                        )}
                    </div>

                    <div className="border-t border-gray-300 pt-4 mt-4 space-y-2">
                        <div className="flex justify-between text-sm text-gray-600"><span>Tạm tính</span><span>{new Intl.NumberFormat('vi-VN').format(subTotal)}đ</span></div>
                        {appliedCoupon && (
                            <div className="flex justify-between text-sm text-green-600 font-medium">
                                <span>Giảm giá ({appliedCoupon.code})</span>
                                <span>-{new Intl.NumberFormat('vi-VN').format(appliedCoupon.discount)}đ</span>
                            </div>
                        )}
                        <div className="flex justify-between text-sm text-gray-600"><span>Phí vận chuyển</span><span className="text-green-600 font-medium">Miễn phí</span></div>
                    </div>
                    <div className="border-t border-gray-300 pt-4 mt-4 flex justify-between font-bold text-xl text-red-600">
                        <span>Tổng cộng</span>
                        <span>{new Intl.NumberFormat('vi-VN').format(totalAmount)}đ</span>
                    </div>
                </div>
            </div>
        </div>
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# BUILD LẠI
# ==============================================================================
echo "🔄 Build & Restart..."
cd /var/www/lica-project/backend
php artisan route:clear

cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Hoàn tất! Vào đặt hàng sẽ thấy danh sách Voucher gợi ý."
