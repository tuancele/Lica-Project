#!/bin/bash

echo "🛠️ Đang sửa lỗi cú pháp trang Checkout (Fix Unterminated template)..."

# ==============================================================================
# GHI ĐÈ FILE SHIPPING PAGE (Code sạch, không escape thừa)
# ==============================================================================
cat << 'EOF' > /var/www/lica-project/apps/user/app/order/shipping/page.tsx
"use client";

import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { MapPin, Phone, User, Truck, Banknote, CreditCard, Loader2, Ticket } from "lucide-react";
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

  const cartItems = [{ product_id: 1, quantity: 1, name: "Sản phẩm Demo", price: 500000 }];
  const subTotal = cartItems.reduce((acc, item) => acc + (item.price * item.quantity), 0);
  const totalAmount = subTotal - (appliedCoupon?.discount || 0);

  useEffect(() => {
    const initData = async () => {
      try {
        const token = localStorage.getItem("token");
        if (token) {
            const apiUrl = process.env.NEXT_PUBLIC_API_URL;
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

  const handleApplyCoupon = async () => {
    if(!couponCode.trim()) return;
    setCheckingCoupon(true);
    setCouponMsg("");
    try {
        const res = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/check-coupon`, {
            code: couponCode,
            items: cartItems.map(i => ({ product_id: i.product_id, quantity: i.quantity }))
        });
        setAppliedCoupon({ code: couponCode, discount: res.data.data.discount });
        setCouponMsg("Áp dụng mã thành công!");
    } catch (err: any) {
        setAppliedCoupon(null);
        setCouponMsg(err.response?.data?.message || "Mã không hợp lệ");
    } finally { setCheckingCoupon(false); }
  };

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
                        <label className="text-xs font-medium text-gray-500 mb-1 block">Khu vực (Phường/Xã, Quận/Huyện) *</label>
                        <SmartLocationInput onSelect={(d) => { setAddressData(p=>({...p, province_code: d.province_code, district_code: d.district_code, ward_code: d.ward_code})); setFullLocationLabel(d.label); setLocationNames({province: d.province_name, district: d.district_name, ward: d.ward_name}); }} initialLabel={fullLocationLabel} />
                    </div>
                    <div>
                        <label className="text-xs font-medium text-gray-500 mb-1 block">Chi tiết (Số nhà, đường) *</label>
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
                    
                    {/* COUPON INPUT */}
                    <div className="border-t border-dashed border-gray-300 pt-4 mt-4">
                        <label className="text-xs font-bold text-gray-500 uppercase mb-2 block flex items-center gap-1"><Ticket size={14}/> Mã giảm giá</label>
                        <div className="flex gap-2">
                            <input type="text" placeholder="Nhập mã" className="flex-1 border rounded p-2 text-sm uppercase font-bold text-gray-700 outline-none focus:border-blue-500" 
                                value={couponCode} onChange={e => setCouponCode(e.target.value.toUpperCase())} disabled={!!appliedCoupon} />
                            {appliedCoupon ? (
                                <button type="button" onClick={handleRemoveCoupon} className="bg-gray-200 text-gray-600 px-3 py-2 rounded text-sm font-bold hover:bg-gray-300 transition">Xóa</button>
                            ) : (
                                <button type="button" onClick={handleApplyCoupon} disabled={checkingCoupon} className="bg-blue-600 text-white px-3 py-2 rounded text-sm font-bold hover:bg-blue-700 disabled:opacity-70 transition">Áp dụng</button>
                            )}
                        </div>
                        {couponMsg && <div className={`text-xs mt-2 font-medium ${appliedCoupon ? 'text-green-600' : 'text-red-600'}`}>{couponMsg}</div>}
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
echo "🔄 Build lại Frontend User..."
cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Hoàn tất! Trang đặt hàng đã hoạt động trở lại."
