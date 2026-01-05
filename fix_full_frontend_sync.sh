#!/bin/bash

FE_ROOT="/var/www/lica-project/apps/user"

echo "========================================================"
echo "   ĐỒNG BỘ HÓA TOÀN BỘ FRONTEND (FIX ALL LOCATION BUGS)"
echo "========================================================"

# 1. Đảm bảo Component SmartLocationInput chuẩn nhất
echo ">>> [1/4] Chuẩn hóa SmartLocationInput..."
cat << 'EOF' > $FE_ROOT/components/common/SmartLocationInput.tsx
'use client';

import { useState, useEffect } from 'react';
import { LocationService, LocationOption } from '@/services/location.service';

interface LocationData {
  province?: LocationOption;
  district?: LocationOption;
  ward?: LocationOption;
  fullAddress: string;
}

interface Props {
  // Tên prop chuẩn dùng cho toàn bộ dự án
  onLocationChange: (data: LocationData) => void;
}

export default function SmartLocationInput({ onLocationChange }: Props) {
  const [provinces, setProvinces] = useState<LocationOption[]>([]);
  const [districts, setDistricts] = useState<LocationOption[]>([]);
  const [wards, setWards] = useState<LocationOption[]>([]);

  const [selectedProvince, setSelectedProvince] = useState<string>('');
  const [selectedDistrict, setSelectedDistrict] = useState<string>('');
  const [selectedWard, setSelectedWard] = useState<string>('');
  const [street, setStreet] = useState('');

  useEffect(() => {
    LocationService.getProvinces().then(setProvinces);
  }, []);

  useEffect(() => {
    if (selectedProvince) {
      setDistricts([]); setWards([]); setSelectedDistrict(''); setSelectedWard('');
      LocationService.getDistricts(selectedProvince).then(setDistricts);
    }
  }, [selectedProvince]);

  useEffect(() => {
    if (selectedDistrict) {
      setWards([]); setSelectedWard('');
      LocationService.getWards(selectedDistrict).then(setWards);
    }
  }, [selectedDistrict]);

  useEffect(() => {
    const province = provinces.find(p => p.code === selectedProvince);
    const district = districts.find(d => d.code === selectedDistrict);
    const ward = wards.find(w => w.code === selectedWard);

    // Logic tạo địa chỉ hiển thị
    const parts = [street, ward?.full_name, district?.full_name, province?.full_name].filter(Boolean);
    
    // Gửi dữ liệu ra ngoài
    onLocationChange({
      province,
      district,
      ward,
      fullAddress: parts.join(', ')
    });
  }, [selectedProvince, selectedDistrict, selectedWard, street, provinces, districts, wards]);

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div>
          <select className="w-full border border-gray-300 rounded-md p-2 text-sm outline-none bg-white"
            value={selectedProvince} onChange={(e) => setSelectedProvince(e.target.value)}>
            <option value="">-- Tỉnh/Thành --</option>
            {provinces.map((p) => <option key={p.code} value={p.code}>{p.full_name || p.name}</option>)}
          </select>
        </div>
        <div>
          <select className="w-full border border-gray-300 rounded-md p-2 text-sm outline-none bg-white disabled:bg-gray-100"
            value={selectedDistrict} onChange={(e) => setSelectedDistrict(e.target.value)} disabled={!selectedProvince}>
            <option value="">-- Quận/Huyện --</option>
            {districts.map((d) => <option key={d.code} value={d.code}>{d.full_name || d.name}</option>)}
          </select>
        </div>
        <div>
          <select className="w-full border border-gray-300 rounded-md p-2 text-sm outline-none bg-white disabled:bg-gray-100"
            value={selectedWard} onChange={(e) => setSelectedWard(e.target.value)} disabled={!selectedDistrict}>
            <option value="">-- Phường/Xã --</option>
            {wards.map((w) => <option key={w.code} value={w.code}>{w.full_name || w.name}</option>)}
          </select>
        </div>
      </div>
      <div>
        <input type="text" className="w-full border border-gray-300 rounded-md p-2 text-sm outline-none focus:border-blue-500 transition"
          placeholder="Số nhà, tên đường..."
          value={street} onChange={(e) => setStreet(e.target.value)}
        />
      </div>
    </div>
  );
}
EOF

# 2. Sửa file PROFILE PAGE (Nơi đang gây lỗi)
echo ">>> [2/4] Fix Profile Page..."
cat << 'EOF' > $FE_ROOT/app/profile/[username]/page.tsx
"use client";
import { useState, useEffect, use } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { User, Package, MapPin, LogOut, Plus, X } from "lucide-react";
import SmartLocationInput from "@/components/common/SmartLocationInput";

export default function ProfilePage({ params }: { params: Promise<{ username: string }> }) {
  const { username } = use(params);
  const router = useRouter();
  const [user, setUser] = useState<any>(null);
  const [activeTab, setActiveTab] = useState("profile");
  const [orders, setOrders] = useState<any[]>([]);
  const [addresses, setAddresses] = useState<any[]>([]);
  
  const [showModal, setShowModal] = useState(false);
  const [newAddr, setNewAddr] = useState({ name: "", phone: "", street: "", province: "", district: "", ward: "", is_default: false });
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const token = localStorage.getItem("token");
    if (!token) { router.push("/login"); return; }

    const fetchData = async () => {
      try {
        const headers = { Authorization: `Bearer ${token}` };
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        
        const meRes = await axios.get(`${apiUrl}/api/v1/profile/me`, { headers });
        setUser(meRes.data.data);

        if (activeTab === "orders") {
          const orderRes = await axios.get(`${apiUrl}/api/v1/profile/orders`, { headers });
          setOrders(orderRes.data.data);
        }
        if (activeTab === "address") {
          const addrRes = await axios.get(`${apiUrl}/api/v1/profile/addresses`, { headers });
          setAddresses(addrRes.data.data);
        }
      } catch (err) {
        localStorage.removeItem("token");
        router.push("/login");
      }
    };
    fetchData();
  }, [activeTab, router]);

  const handleAddAddress = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAddr.province || !newAddr.ward) {
        alert("Vui lòng chọn đầy đủ địa chỉ!");
        return;
    }
    
    setLoading(true);
    try {
        const token = localStorage.getItem("token");
        const payload = {
            name: newAddr.name,
            phone: newAddr.phone,
            address: newAddr.street,
            province_id: newAddr.province,
            district_id: newAddr.district,
            ward_id: newAddr.ward,
            is_default: newAddr.is_default
        };
        await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/profile/addresses`, payload, {
            headers: { Authorization: `Bearer ${token}` }
        });
        
        setShowModal(false);
        setNewAddr({ name: "", phone: "", street: "", province: "", district: "", ward: "", is_default: false });
        
        const addrRes = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/profile/addresses`, { headers: { Authorization: `Bearer ${token}` } });
        setAddresses(addrRes.data.data);
        alert("Đã thêm địa chỉ mới!");
    } catch (err) {
        alert("Lỗi thêm địa chỉ.");
    } finally {
        setLoading(false);
    }
  };

  const handleLogout = () => { localStorage.removeItem("token"); localStorage.removeItem("user"); router.push("/login"); };

  if (!user) return <div className="p-10 text-center">Đang tải hồ sơ...</div>;

  return (
    <div className="min-h-screen bg-gray-50 p-6 font-sans">
      <div className="max-w-5xl mx-auto grid grid-cols-1 md:grid-cols-4 gap-6">
        
        {/* Sidebar */}
        <div className="bg-white rounded-xl shadow-sm p-6 h-fit">
          <div className="flex items-center gap-3 mb-6 pb-6 border-b">
            <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 font-bold text-xl uppercase">{user.name[0]}</div>
            <div><div className="font-bold text-gray-900">{user.name}</div><div className="text-xs text-gray-500">@{user.username}</div></div>
          </div>
          <nav className="space-y-2">
            <button onClick={() => setActiveTab("profile")} className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition ${activeTab === "profile" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}`}><User size={18} /> Hồ sơ</button>
            <button onClick={() => setActiveTab("orders")} className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition ${activeTab === "orders" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}`}><Package size={18} /> Đơn hàng</button>
            <button onClick={() => setActiveTab("address")} className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition ${activeTab === "address" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}`}><MapPin size={18} /> Sổ địa chỉ</button>
            <button onClick={handleLogout} className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg text-red-600 hover:bg-red-50 mt-4 border-t pt-4"><LogOut size={18} /> Đăng xuất</button>
          </nav>
        </div>

        {/* Content */}
        <div className="md:col-span-3 bg-white rounded-xl shadow-sm p-8 relative min-h-[500px]">
          
          {activeTab === "profile" && (
            <div>
              <h2 className="text-xl font-bold text-gray-800 mb-6 pb-4 border-b">Hồ sơ cá nhân</h2>
              <div className="space-y-4 max-w-lg">
                <div className="grid grid-cols-3 gap-4 border-b pb-3"><span className="text-gray-500">Họ tên</span><span className="col-span-2 font-medium">{user.name}</span></div>
                <div className="grid grid-cols-3 gap-4 border-b pb-3"><span className="text-gray-500">Tài khoản</span><span className="col-span-2 font-medium">{user.email || user.phone}</span></div>
                <div className="grid grid-cols-3 gap-4"><span className="text-gray-500">Hạng</span><span className="col-span-2"><span className="bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded-full font-bold uppercase">{user.membership_tier}</span></span></div>
              </div>
            </div>
          )}

          {activeTab === "orders" && (
            <div>
              <h2 className="text-xl font-bold text-gray-800 mb-6 pb-4 border-b">Lịch sử đơn hàng</h2>
              <div className="space-y-4">
                {orders.length > 0 ? orders.map(o => (
                  <div key={o.id} className="border p-5 rounded-xl bg-gray-50/30">
                    <div className="flex justify-between items-start mb-3">
                        <div><div className="font-bold text-lg">#{o.code}</div><div className="text-sm text-gray-500">{new Date(o.created_at).toLocaleString('vi-VN')}</div></div>
                        <div><span className="inline-block px-3 py-1 rounded-full text-xs font-bold uppercase bg-orange-100 text-orange-700">{o.status}</span></div>
                    </div>
                    <div className="border-t border-dashed pt-3 flex justify-between items-center"><span className="text-sm text-gray-500">{o.items?.length || 0} sản phẩm</span><div className="font-bold text-red-600 text-lg">{new Intl.NumberFormat('vi-VN').format(o.total_amount)}đ</div></div>
                  </div>
                )) : <div className="text-center py-10 text-gray-400">Bạn chưa có đơn hàng nào.</div>}
              </div>
            </div>
          )}

          {activeTab === "address" && (
            <div>
              <div className="flex justify-between items-center mb-6 pb-4 border-b">
                <h2 className="text-xl font-bold text-gray-800">Sổ địa chỉ</h2>
                <button onClick={() => setShowModal(true)} className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-bold"><Plus size={18}/> Thêm mới</button>
              </div>
              <div className="grid gap-4">
                {addresses.map(addr => (
                  <div key={addr.id} className="border p-5 rounded-xl relative group">
                    {addr.is_default && <div className="absolute top-0 right-0 bg-blue-500 text-white text-xs px-3 py-1 rounded-bl-xl rounded-tr-lg">Mặc định</div>}
                    <div className="flex items-start gap-3"><MapPin size={20} className="text-gray-400"/><div className="font-bold">{addr.name} | {addr.phone}</div></div>
                    <div className="text-gray-600 mt-1 ml-8">{addr.address}</div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      </div>

      {showModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden">
                <div className="flex justify-between items-center p-5 border-b bg-gray-50"><h3 className="font-bold text-lg">Thêm địa chỉ</h3><button onClick={() => setShowModal(false)}><X size={20}/></button></div>
                <form onSubmit={handleAddAddress} className="p-6 space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                        <input type="text" required className="border p-2 rounded" value={newAddr.name} onChange={e => setNewAddr({...newAddr, name: e.target.value})} placeholder="Họ tên"/>
                        <input type="text" required className="border p-2 rounded" value={newAddr.phone} onChange={e => setNewAddr({...newAddr, phone: e.target.value})} placeholder="SĐT"/>
                    </div>
                    {/* FIX: Dùng đúng prop onLocationChange và mapping dữ liệu đúng */}
                    <SmartLocationInput 
                        onLocationChange={(data) => setNewAddr({
                            ...newAddr, 
                            street: data.fullAddress,
                            province: data.province?.code || '',
                            district: data.district?.code || '',
                            ward: data.ward?.code || ''
                        })} 
                    />
                    <label className="flex items-center gap-2"><input type="checkbox" checked={newAddr.is_default} onChange={e => setNewAddr({...newAddr, is_default: e.target.checked})} /> Đặt mặc định</label>
                    <button type="submit" disabled={loading} className="w-full bg-blue-600 text-white py-3 rounded font-bold">{loading ? "Đang lưu..." : "Lưu"}</button>
                </form>
            </div>
        </div>
      )}
    </div>
  );
}
EOF

# 3. Đảm bảo Shipping Page cũng dùng đúng chuẩn
echo ">>> [3/4] Verify Shipping Page..."
sed -i 's/onSelect={/onLocationChange={/g' $FE_ROOT/app/order/shipping/page.tsx

# 4. Xóa Cache Build & Rebuild
echo ">>> [4/4] Clean & Rebuild..."
cd $FE_ROOT
rm -rf .next
npm run build

echo "========================================================"
echo "   ĐÃ KHẮC PHỤC TOÀN BỘ LỖI."
echo "   VUI LÒNG RESTART PM2 SAU KHI THẤY 'Compiled successfully'"
echo "========================================================"
