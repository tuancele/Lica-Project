#!/bin/bash

echo "🚀 Đang nâng cấp Profile: Tích hợp Tìm kiếm địa chỉ thông minh..."

# ==============================================================================
# CẬP NHẬT FILE PROFILE (apps/user/app/profile/[username]/page.tsx)
# ==============================================================================
cat << 'EOF' > /var/www/lica-project/apps/user/app/profile/[username]/page.tsx
"use client";
import { useState, useEffect, use } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { User, Package, MapPin, Heart, Award, LogOut, Plus, X, Trash2 } from "lucide-react";
import SmartLocationInput from "@/components/common/SmartLocationInput";

export default function ProfilePage({ params }: { params: Promise<{ username: string }> }) {
  const { username } = use(params);
  const router = useRouter();
  const [user, setUser] = useState<any>(null);
  const [activeTab, setActiveTab] = useState("profile");
  const [orders, setOrders] = useState<any[]>([]);
  const [addresses, setAddresses] = useState<any[]>([]);
  
  // State cho Modal thêm địa chỉ
  const [showModal, setShowModal] = useState(false);
  const [newAddr, setNewAddr] = useState({ name: "", phone: "", street: "", province: "", district: "", ward: "", is_default: false });
  const [loading, setLoading] = useState(false);

  // Load Data
  useEffect(() => {
    const token = localStorage.getItem("token");
    if (!token) { router.push("/login"); return; }

    const fetchData = async () => {
      try {
        const headers = { Authorization: `Bearer ${token}` };
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        
        // Load User
        const meRes = await axios.get(`${apiUrl}/api/v1/profile/me`, { headers });
        setUser(meRes.data.data);

        // Load Tab Data
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

  // Handle Add Address
  const handleAddAddress = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newAddr.province || !newAddr.ward) {
        alert("Vui lòng tìm và chọn Phường/Xã từ danh sách gợi ý.");
        return;
    }
    
    setLoading(true);
    try {
        const token = localStorage.getItem("token");
        const payload = {
            name: newAddr.name,
            phone: newAddr.phone,
            address: newAddr.street, // Địa chỉ cụ thể
            province_id: newAddr.province,
            district_id: newAddr.district,
            ward_id: newAddr.ward,
            is_default: newAddr.is_default
        };
        await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/profile/addresses`, payload, {
            headers: { Authorization: `Bearer ${token}` }
        });
        
        // Reset & Reload
        setShowModal(false);
        setNewAddr({ name: "", phone: "", street: "", province: "", district: "", ward: "", is_default: false });
        
        const addrRes = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/profile/addresses`, { headers: { Authorization: `Bearer ${token}` } });
        setAddresses(addrRes.data.data);
        alert("Đã thêm địa chỉ mới!");
    } catch (err) {
        alert("Lỗi thêm địa chỉ. Vui lòng thử lại.");
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
          
          {/* TAB: PROFILE */}
          {activeTab === "profile" && (
            <div>
              <h2 className="text-xl font-bold text-gray-800 mb-6 pb-4 border-b">Hồ sơ cá nhân</h2>
              <div className="space-y-4 max-w-lg">
                <div className="grid grid-cols-3 gap-4 border-b pb-3">
                  <span className="text-gray-500">Họ tên</span><span className="col-span-2 font-medium">{user.name}</span>
                </div>
                <div className="grid grid-cols-3 gap-4 border-b pb-3">
                  <span className="text-gray-500">Tài khoản</span><span className="col-span-2 font-medium">{user.email || user.phone}</span>
                </div>
                <div className="grid grid-cols-3 gap-4">
                  <span className="text-gray-500">Hạng thành viên</span>
                  <span className="col-span-2"><span className="bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded-full font-bold uppercase">{user.membership_tier}</span></span>
                </div>
              </div>
            </div>
          )}

          {/* TAB: ORDERS */}
          {activeTab === "orders" && (
            <div>
              <h2 className="text-xl font-bold text-gray-800 mb-6 pb-4 border-b">Lịch sử đơn hàng</h2>
              <div className="space-y-4">
                {orders.length > 0 ? orders.map(o => (
                  <div key={o.id} className="border border-gray-200 p-5 rounded-xl hover:border-blue-300 transition bg-gray-50/30">
                    <div className="flex justify-between items-start mb-3">
                        <div>
                            <div className="font-bold text-lg text-gray-800">#{o.code}</div>
                            <div className="text-sm text-gray-500">{new Date(o.created_at).toLocaleString('vi-VN')}</div>
                        </div>
                        <div className="text-right">
                             <span className={`inline-block px-3 py-1 rounded-full text-xs font-bold uppercase ${o.status === 'completed' ? 'bg-green-100 text-green-700' : 'bg-orange-100 text-orange-700'}`}>{o.status}</span>
                        </div>
                    </div>
                    <div className="border-t border-dashed pt-3 flex justify-between items-center">
                        <span className="text-sm text-gray-500">{o.items?.length || 0} sản phẩm</span>
                        <div className="font-bold text-red-600 text-lg">{new Intl.NumberFormat('vi-VN').format(o.total_amount)}đ</div>
                    </div>
                  </div>
                )) : <div className="text-center py-10 text-gray-400">Bạn chưa có đơn hàng nào.</div>}
              </div>
            </div>
          )}

          {/* TAB: ADDRESS (SMART) */}
          {activeTab === "address" && (
            <div>
              <div className="flex justify-between items-center mb-6 pb-4 border-b">
                <h2 className="text-xl font-bold text-gray-800">Sổ địa chỉ nhận hàng</h2>
                <button onClick={() => setShowModal(true)} className="flex items-center gap-2 px-4 py-2.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-bold shadow-sm transition">
                    <Plus size={18}/> Thêm địa chỉ mới
                </button>
              </div>
              
              <div className="grid gap-4">
                {addresses.length > 0 ? addresses.map(addr => (
                  <div key={addr.id} className={`border p-5 rounded-xl relative group transition ${addr.is_default ? 'border-blue-500 bg-blue-50/30 ring-1 ring-blue-500' : 'border-gray-200 hover:border-gray-300'}`}>
                    {addr.is_default && (
                        <div className="absolute top-0 right-0 bg-blue-500 text-white text-xs px-3 py-1 rounded-bl-xl rounded-tr-lg font-bold shadow-sm">Mặc định</div>
                    )}
                    
                    <div className="flex items-start gap-3 mb-2">
                        <MapPin size={20} className="text-gray-400 mt-0.5"/>
                        <div>
                            <div className="font-bold text-gray-900">{addr.name} <span className="text-gray-400 font-normal mx-2">|</span> {addr.phone}</div>
                            <div className="text-gray-600 mt-1 leading-relaxed">{addr.address}</div>
                            {/* Note: Ở đây hiển thị address string, nếu muốn hiển thị Tỉnh/Huyện thì backend cần join bảng hoặc lưu full string vào address */}
                        </div>
                    </div>
                    
                    {/* Actions (Delete button placeholder) */}
                    {!addr.is_default && (
                        <div className="absolute bottom-4 right-4 opacity-0 group-hover:opacity-100 transition">
                            {/* Logic xóa sẽ thêm sau */}
                        </div>
                    )}
                  </div>
                )) : (
                    <div className="text-center py-12 bg-gray-50 rounded-xl border border-dashed border-gray-300">
                        <MapPin size={48} className="mx-auto text-gray-300 mb-3"/>
                        <p className="text-gray-500">Bạn chưa lưu địa chỉ nào.</p>
                    </div>
                )}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* MODAL ADD ADDRESS (SMART INPUT) */}
      {showModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in duration-200">
            <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden">
                <div className="flex justify-between items-center p-5 border-b bg-gray-50">
                    <h3 className="font-bold text-lg text-gray-800">Thêm địa chỉ mới</h3>
                    <button onClick={() => setShowModal(false)} className="text-gray-400 hover:text-red-500 transition bg-white p-1 rounded-full border hover:border-red-200"><X size={20}/></button>
                </div>
                
                <form onSubmit={handleAddAddress} className="p-6 space-y-5">
                    {/* Họ tên & SĐT */}
                    <div className="grid grid-cols-2 gap-4">
                        <div>
                            <label className="block text-xs font-bold text-gray-500 mb-1 uppercase">Họ và tên</label>
                            <input type="text" required className="w-full border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-blue-500" 
                                value={newAddr.name} onChange={e => setNewAddr({...newAddr, name: e.target.value})} placeholder="VD: Nguyễn Văn A"/>
                        </div>
                        <div>
                            <label className="block text-xs font-bold text-gray-500 mb-1 uppercase">Số điện thoại</label>
                            <input type="text" required className="w-full border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-blue-500" 
                                value={newAddr.phone} onChange={e => setNewAddr({...newAddr, phone: e.target.value})} placeholder="VD: 09xxxx"/>
                        </div>
                    </div>

                    {/* SMART LOCATION INPUT */}
                    <div>
                        <label className="block text-xs font-bold text-gray-500 mb-1 uppercase">Khu vực (Phường/Xã, Quận/Huyện)</label>
                        <SmartLocationInput 
                            onSelect={(data) => setNewAddr({...newAddr, province: data.province_code, district: data.district_code, ward: data.ward_code})} 
                        />
                        <p className="text-xs text-gray-400 mt-1.5 italic">Gõ tên xã/phường để tìm nhanh (Ví dụ: "đại mỗ", "yên hòa"...)</p>
                    </div>

                    {/* STREET */}
                    <div>
                        <label className="block text-xs font-bold text-gray-500 mb-1 uppercase">Địa chỉ cụ thể</label>
                        <input type="text" required className="w-full border border-gray-300 rounded-lg p-2.5 outline-none focus:ring-2 focus:ring-blue-500" 
                            value={newAddr.street} onChange={e => setNewAddr({...newAddr, street: e.target.value})} placeholder="Số nhà, ngõ, tên đường..."/>
                    </div>

                    {/* DEFAULT CHECKBOX */}
                    <label className="flex items-center gap-3 p-3 border rounded-lg cursor-pointer hover:bg-gray-50 transition">
                        <input type="checkbox" className="w-5 h-5 accent-blue-600" checked={newAddr.is_default} onChange={e => setNewAddr({...newAddr, is_default: e.target.checked})} />
                        <span className="text-sm font-medium text-gray-700">Đặt làm địa chỉ mặc định</span>
                    </label>

                    <button type="submit" disabled={loading} className="w-full bg-blue-600 text-white py-3.5 rounded-xl font-bold hover:bg-blue-700 transition shadow-lg shadow-blue-200">
                        {loading ? "Đang lưu..." : "Lưu địa chỉ"}
                    </button>
                </form>
            </div>
        </div>
      )}
    </div>
  );
}
EOF

# ==============================================================================
# BUILD LẠI FRONTEND
# ==============================================================================
echo "🔄 Build lại User App..."
cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Hoàn tất! Vào Profile -> Sổ địa chỉ để trải nghiệm tính năng tìm kiếm thông minh."
