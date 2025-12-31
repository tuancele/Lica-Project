"use client";
import { useState, useEffect, use } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { User, Package, MapPin, Heart, Award, LogOut, Plus, X } from "lucide-react";

interface Location { code: string; name: string; }

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
  const [provinces, setProvinces] = useState<Location[]>([]);
  const [districts, setDistricts] = useState<Location[]>([]);
  const [wards, setWards] = useState<Location[]>([]);

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
          // Load Province luôn để dùng cho modal
          const provRes = await axios.get(`${apiUrl}/api/v1/location/provinces`);
          setProvinces(provRes.data.data);
        }
      } catch (err) {
        localStorage.removeItem("token");
        router.push("/login");
      }
    };
    fetchData();
  }, [activeTab, router]);

  // Logic load địa chính cho Modal
  useEffect(() => {
    if (!newAddr.province) { setDistricts([]); return; }
    axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/location/districts/${newAddr.province}`).then(res => setDistricts(res.data.data));
  }, [newAddr.province]);

  useEffect(() => {
    if (!newAddr.district) { setWards([]); return; }
    axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/location/wards/${newAddr.district}`).then(res => setWards(res.data.data));
  }, [newAddr.district]);

  const handleAddAddress = async (e: React.FormEvent) => {
    e.preventDefault();
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
        alert("Thêm địa chỉ thành công!");
        setShowModal(false);
        // Reload list
        const addrRes = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/profile/addresses`, { headers: { Authorization: `Bearer ${token}` } });
        setAddresses(addrRes.data.data);
    } catch (err) {
        alert("Lỗi thêm địa chỉ");
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
            <button onClick={() => setActiveTab("address")} className={`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition ${activeTab === "address" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}`}><MapPin size={18} /> Địa chỉ</button>
            <button onClick={handleLogout} className="w-full flex items-center gap-3 px-4 py-2.5 rounded-lg text-red-600 hover:bg-red-50 mt-4 border-t pt-4"><LogOut size={18} /> Đăng xuất</button>
          </nav>
        </div>

        {/* Content */}
        <div className="md:col-span-3 bg-white rounded-xl shadow-sm p-8 relative">
          {activeTab === "profile" && (
            <div>
              <h2 className="text-xl font-bold text-gray-800 mb-6 pb-4 border-b">Hồ sơ</h2>
              <div className="space-y-4">
                <div className="grid grid-cols-3 gap-4">
                  <span className="text-gray-500">Họ tên</span><span className="col-span-2 font-medium">{user.name}</span>
                </div>
                <div className="grid grid-cols-3 gap-4">
                  <span className="text-gray-500">Email/SĐT</span><span className="col-span-2 font-medium">{user.email || user.phone}</span>
                </div>
              </div>
            </div>
          )}

          {activeTab === "orders" && (
            <div>
              <h2 className="text-xl font-bold text-gray-800 mb-6 pb-4 border-b">Đơn hàng</h2>
              <div className="space-y-4">
                {orders.length > 0 ? orders.map(o => (
                  <div key={o.id} className="border p-4 rounded-lg flex justify-between items-center">
                    <div>
                        <div className="font-bold">#{o.code}</div>
                        <div className="text-sm text-gray-500">{new Date(o.created_at).toLocaleDateString('vi-VN')}</div>
                    </div>
                    <div className="text-right">
                        <div className="font-bold text-red-600">{new Intl.NumberFormat('vi-VN').format(o.total_amount)}đ</div>
                        <span className="text-xs bg-gray-100 px-2 py-1 rounded uppercase">{o.status}</span>
                    </div>
                  </div>
                )) : <p className="text-gray-500">Chưa có đơn hàng.</p>}
              </div>
            </div>
          )}

          {activeTab === "address" && (
            <div>
              <div className="flex justify-between items-center mb-6 pb-4 border-b">
                <h2 className="text-xl font-bold text-gray-800">Sổ địa chỉ</h2>
                <button onClick={() => setShowModal(true)} className="flex items-center gap-2 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-medium"><Plus size={16}/> Thêm địa chỉ</button>
              </div>
              <div className="space-y-4">
                {addresses.length > 0 ? addresses.map(addr => (
                  <div key={addr.id} className="border p-4 rounded-lg relative">
                    {addr.is_default && <span className="absolute top-4 right-4 text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded">Mặc định</span>}
                    <div className="font-bold">{addr.name} <span className="font-normal text-gray-500">| {addr.phone}</span></div>
                    <div className="text-gray-600 mt-1">{addr.address}</div>
                  </div>
                )) : <p className="text-gray-500">Chưa có địa chỉ nào.</p>}
              </div>
            </div>
          )}
        </div>
      </div>

      {/* MODAL ADD ADDRESS */}
      {showModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-xl shadow-xl w-full max-w-lg overflow-hidden">
                <div className="flex justify-between items-center p-4 border-b">
                    <h3 className="font-bold text-lg">Thêm địa chỉ mới</h3>
                    <button onClick={() => setShowModal(false)} className="text-gray-500 hover:text-red-500"><X size={20}/></button>
                </div>
                <form onSubmit={handleAddAddress} className="p-6 space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                        <input type="text" placeholder="Họ tên" required className="border p-2 rounded" value={newAddr.name} onChange={e => setNewAddr({...newAddr, name: e.target.value})} />
                        <input type="text" placeholder="Số điện thoại" required className="border p-2 rounded" value={newAddr.phone} onChange={e => setNewAddr({...newAddr, phone: e.target.value})} />
                    </div>
                    <div className="grid grid-cols-3 gap-2">
                        <select className="border p-2 rounded text-sm" required value={newAddr.province} onChange={e => setNewAddr({...newAddr, province: e.target.value, district: '', ward: ''})}>
                            <option value="">Tỉnh/TP</option>
                            {provinces.map(p => <option key={p.code} value={p.code}>{p.name}</option>)}
                        </select>
                        <select className="border p-2 rounded text-sm" required value={newAddr.district} onChange={e => setNewAddr({...newAddr, district: e.target.value, ward: ''})}>
                            <option value="">Quận/Huyện</option>
                            {districts.map(d => <option key={d.code} value={d.code}>{d.name}</option>)}
                        </select>
                        <select className="border p-2 rounded text-sm" required value={newAddr.ward} onChange={e => setNewAddr({...newAddr, ward: e.target.value})}>
                            <option value="">Phường/Xã</option>
                            {wards.map(w => <option key={w.code} value={w.code}>{w.name}</option>)}
                        </select>
                    </div>
                    <input type="text" placeholder="Địa chỉ cụ thể (Số nhà, đường)" required className="border p-2 rounded w-full" value={newAddr.street} onChange={e => setNewAddr({...newAddr, street: e.target.value})} />
                    <label className="flex items-center gap-2">
                        <input type="checkbox" checked={newAddr.is_default} onChange={e => setNewAddr({...newAddr, is_default: e.target.checked})} />
                        <span className="text-sm">Đặt làm địa chỉ mặc định</span>
                    </label>
                    <button type="submit" className="w-full bg-blue-600 text-white py-3 rounded-lg font-bold hover:bg-blue-700">Lưu địa chỉ</button>
                </form>
            </div>
        </div>
      )}
    </div>
  );
}
