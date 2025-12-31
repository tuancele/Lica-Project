#!/bin/bash

echo "🛠️ Đang bổ sung Ghi chú & Phương thức thanh toán vào trang Checkout..."

# ==============================================================================
# SỬA FILE SHIPPING (app/order/shipping/page.tsx) - BẢN FULL
# ==============================================================================
cat << 'EOF' > /var/www/lica-project/apps/user/app/order/shipping/page.tsx
"use client";

import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { MapPin, Phone, User, Loader2, CreditCard, Truck, Banknote } from "lucide-react";

interface Location { code: string; name: string; }

export default function ShippingPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [initializing, setInitializing] = useState(true);
  const [error, setError] = useState("");

  const [provinces, setProvinces] = useState<Location[]>([]);
  const [districts, setDistricts] = useState<Location[]>([]);
  const [wards, setWards] = useState<Location[]>([]);

  const [formData, setFormData] = useState({
    customer_name: "", customer_phone: "", customer_email: "",
    payment_method: "cash_on_delivery", note: ""
  });

  const [addressData, setAddressData] = useState({
    street: "", province_code: "", district_code: "", ward_code: ""
  });

  const [locationNames, setLocationNames] = useState({ province: "", district: "", ward: "" });

  const cartItems = [{ product_id: 1, quantity: 1, name: "Sản phẩm Demo", price: 500000 }];
  const totalAmount = cartItems.reduce((acc, item) => acc + (item.price * item.quantity), 0);

  // 1. INIT DATA & AUTO FILL
  useEffect(() => {
    const initData = async () => {
      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.lica.vn";
        
        // 1. Load Provinces
        const provRes = await axios.get(`${apiUrl}/api/v1/location/provinces`);
        setProvinces(provRes.data.data);

        // 2. Check User & Auto fill
        const token = localStorage.getItem("token");
        if (token) {
            try {
                const [meRes, addrRes] = await Promise.all([
                    axios.get(`${apiUrl}/api/v1/profile/me`, { headers: { Authorization: `Bearer ${token}` } }),
                    axios.get(`${apiUrl}/api/v1/profile/addresses`, { headers: { Authorization: `Bearer ${token}` } })
                ]);

                const user = meRes.data.data;
                const addresses = addrRes.data.data;
                const defaultAddr = addresses.find((a: any) => a.is_default) || addresses[0];

                setFormData(prev => ({
                    ...prev,
                    customer_name: defaultAddr ? defaultAddr.name : user.name,
                    customer_phone: defaultAddr ? defaultAddr.phone : (user.phone || ""),
                    customer_email: user.email || ""
                }));

                if (defaultAddr && defaultAddr.province_id) {
                    setAddressData({
                        street: defaultAddr.address,
                        province_code: defaultAddr.province_id,
                        district_code: defaultAddr.district_id,
                        ward_code: defaultAddr.ward_id
                    });

                    const dRes = await axios.get(`${apiUrl}/api/v1/location/districts/${defaultAddr.province_id}`);
                    setDistricts(dRes.data.data);

                    const wRes = await axios.get(`${apiUrl}/api/v1/location/wards/${defaultAddr.district_id}`);
                    setWards(wRes.data.data);
                    
                    const pName = provRes.data.data.find((x:any) => x.code == defaultAddr.province_id)?.name;
                    const dName = dRes.data.data.find((x:any) => x.code == defaultAddr.district_id)?.name;
                    const wName = wRes.data.data.find((x:any) => x.code == defaultAddr.ward_id)?.name;
                    
                    setLocationNames({ province: pName || "", district: dName || "", ward: wName || "" });
                }
            } catch (err) { console.log("Guest or Token expired"); }
        }
      } catch (err) { console.error(err); } finally { setInitializing(false); }
    };
    initData();
  }, []);

  // Handle Location Changes
  useEffect(() => {
    if (!initializing && addressData.province_code) {
        axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/location/districts/${addressData.province_code}`)
             .then(res => setDistricts(res.data.data));
        const p = provinces.find(x => x.code == addressData.province_code);
        if(p) setLocationNames(prev => ({...prev, province: p.name}));
    }
  }, [addressData.province_code, initializing]);

  useEffect(() => {
    if (!initializing && addressData.district_code) {
        axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/location/wards/${addressData.district_code}`)
             .then(res => setWards(res.data.data));
        const d = districts.find(x => x.code == addressData.district_code);
        if(d) setLocationNames(prev => ({...prev, district: d.name}));
    }
  }, [addressData.district_code, initializing]);

  useEffect(() => {
    const w = wards.find(x => x.code == addressData.ward_code);
    if(w) setLocationNames(prev => ({...prev, ward: w.name}));
  }, [addressData.ward_code]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    if (!addressData.street || !addressData.province_code) { setError("Vui lòng điền đủ địa chỉ"); setLoading(false); return; }

    try {
      const finalAddress = `${addressData.street}, ${locationNames.ward}, ${locationNames.district}, ${locationNames.province}`;
      const token = localStorage.getItem("token");
      const headers = token ? { Authorization: `Bearer ${token}` } : {};
      
      const res = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/checkout`, {
        ...formData, shipping_address: finalAddress,
        items: cartItems.map(i => ({ product_id: i.product_id, quantity: i.quantity }))
      }, { headers });

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
            {/* LEFT COLUMN: FORM */}
            <form onSubmit={handleSubmit} className="md:col-span-2 space-y-6">
                
                {/* 1. THÔNG TIN CÁ NHÂN */}
                <div className="grid grid-cols-2 gap-4">
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Họ tên *</label>
                        <div className="relative">
                            <User size={16} className="absolute left-3 top-3 text-gray-400"/>
                            <input className="w-full border rounded-lg pl-9 pr-3 py-2.5 focus:ring-2 focus:ring-blue-500 outline-none transition" value={formData.customer_name} onChange={e => setFormData({...formData, customer_name: e.target.value})} required placeholder="Nguyễn Văn A" />
                        </div>
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-gray-700 mb-1">Số điện thoại *</label>
                        <div className="relative">
                            <Phone size={16} className="absolute left-3 top-3 text-gray-400"/>
                            <input className="w-full border rounded-lg pl-9 pr-3 py-2.5 focus:ring-2 focus:ring-blue-500 outline-none transition" value={formData.customer_phone} onChange={e => setFormData({...formData, customer_phone: e.target.value})} required placeholder="09xxxx" />
                        </div>
                    </div>
                </div>

                {/* 2. ĐỊA CHỈ */}
                <div className="bg-gray-50 p-5 rounded-xl border border-gray-200">
                    <h3 className="text-sm font-bold text-gray-800 uppercase mb-3 flex items-center gap-2"><Truck size={16}/> Địa chỉ nhận hàng</h3>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
                        <select className="border rounded-lg p-2.5 text-sm bg-white" value={addressData.province_code} onChange={e => setAddressData({...addressData, province_code: e.target.value, district_code: '', ward_code: ''})}>
                            <option value="">-- Tỉnh/TP --</option>
                            {provinces.map(p => <option key={p.code} value={p.code}>{p.name}</option>)}
                        </select>
                        <select className="border rounded-lg p-2.5 text-sm bg-white" value={addressData.district_code} onChange={e => setAddressData({...addressData, district_code: e.target.value, ward_code: ''})} disabled={!addressData.province_code}>
                            <option value="">-- Quận/Huyện --</option>
                            {districts.map(d => <option key={d.code} value={d.code}>{d.name}</option>)}
                        </select>
                        <select className="border rounded-lg p-2.5 text-sm bg-white" value={addressData.ward_code} onChange={e => setAddressData({...addressData, ward_code: e.target.value})} disabled={!addressData.district_code}>
                            <option value="">-- Phường/Xã --</option>
                            {wards.map(w => <option key={w.code} value={w.code}>{w.name}</option>)}
                        </select>
                    </div>
                    <input className="w-full border rounded-lg p-2.5 text-sm" placeholder="Số nhà, tên đường, tòa nhà..." value={addressData.street} onChange={e => setAddressData({...addressData, street: e.target.value})} required />
                </div>

                {/* 3. GHI CHÚ */}
                <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Ghi chú đơn hàng (Tùy chọn)</label>
                    <textarea 
                        className="w-full border rounded-lg p-3 text-sm focus:ring-2 focus:ring-blue-500 outline-none transition" 
                        rows={2}
                        placeholder="Ví dụ: Giao hàng giờ hành chính, gọi trước khi giao..." 
                        value={formData.note} 
                        onChange={e => setFormData({...formData, note: e.target.value})}
                    ></textarea>
                </div>

                {/* 4. PHƯƠNG THỨC THANH TOÁN */}
                <div>
                    <label className="block text-sm font-medium text-gray-700 mb-2">Phương thức thanh toán</label>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                        <label className={`border rounded-lg p-4 flex items-center gap-3 cursor-pointer transition relative ${formData.payment_method === 'cash_on_delivery' ? 'border-blue-600 bg-blue-50 ring-1 ring-blue-600' : 'hover:bg-gray-50'}`}>
                            <input type="radio" name="payment_method" value="cash_on_delivery" checked={formData.payment_method === 'cash_on_delivery'} onChange={e => setFormData({...formData, payment_method: e.target.value})} className="accent-blue-600 w-5 h-5"/>
                            <div className="flex items-center gap-2">
                                <Banknote size={20} className="text-green-600"/>
                                <span className="text-sm font-medium">Thanh toán khi nhận hàng (COD)</span>
                            </div>
                        </label>
                        
                        <label className={`border rounded-lg p-4 flex items-center gap-3 cursor-pointer transition relative ${formData.payment_method === 'banking' ? 'border-blue-600 bg-blue-50 ring-1 ring-blue-600' : 'hover:bg-gray-50'}`}>
                            <input type="radio" name="payment_method" value="banking" checked={formData.payment_method === 'banking'} onChange={e => setFormData({...formData, payment_method: e.target.value})} className="accent-blue-600 w-5 h-5"/>
                            <div className="flex items-center gap-2">
                                <CreditCard size={20} className="text-blue-600"/>
                                <span className="text-sm font-medium">Chuyển khoản ngân hàng</span>
                            </div>
                        </label>
                    </div>
                </div>
                
                {error && <div className="bg-red-50 text-red-600 p-3 rounded-lg border border-red-200 text-sm">{error}</div>}

                <button type="submit" disabled={loading} className="w-full bg-red-600 text-white font-bold py-4 rounded-lg hover:bg-red-700 transition shadow-lg shadow-red-200 text-lg uppercase">
                    {loading ? "Đang xử lý..." : `ĐẶT HÀNG NGAY (${new Intl.NumberFormat('vi-VN').format(totalAmount)}đ)`}
                </button>
            </form>

            {/* RIGHT COLUMN: SUMMARY */}
            <div className="h-fit space-y-4">
                <div className="bg-gray-50 p-5 rounded-xl border border-gray-200">
                    <h2 className="font-bold text-gray-800 border-b border-gray-300 pb-3 mb-4 text-sm uppercase">Tóm tắt đơn hàng</h2>
                    <div className="space-y-3 max-h-60 overflow-y-auto pr-1">
                        {cartItems.map((i, idx) => (
                            <div key={idx} className="flex justify-between text-sm mb-2 group">
                                <span className="group-hover:text-blue-600 transition">{i.name} <span className="text-gray-500">x{i.quantity}</span></span>
                                <span className="font-medium">{new Intl.NumberFormat('vi-VN').format(i.price * i.quantity)}đ</span>
                            </div>
                        ))}
                    </div>
                    <div className="border-t border-dashed border-gray-300 pt-4 mt-4 space-y-2">
                        <div className="flex justify-between text-sm text-gray-600"><span>Tạm tính</span><span>{new Intl.NumberFormat('vi-VN').format(totalAmount)}đ</span></div>
                        <div className="flex justify-between text-sm text-gray-600"><span>Phí vận chuyển</span><span className="text-green-600 font-medium">Miễn phí</span></div>
                    </div>
                    <div className="border-t border-gray-300 pt-4 mt-4 flex justify-between font-bold text-xl text-red-600">
                        <span>Tổng cộng</span>
                        <span>{new Intl.NumberFormat('vi-VN').format(totalAmount)}đ</span>
                    </div>
                </div>
                <div className="text-xs text-center text-gray-400">
                    Nhấn "Đặt hàng ngay" đồng nghĩa với việc bạn đồng ý tuân theo Điều khoản Lica.vn
                </div>
            </div>
        </div>
      </div>
    </div>
  );
}
EOF

echo "🔄 Build lại Frontend..."
cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Đã bổ sung Ghi chú & Thanh toán thành công! Bạn hãy tải lại trang."
