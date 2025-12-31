#!/bin/bash

echo "🚀 Đang sửa lỗi Thêm địa chỉ & Tự động điền khi Checkout..."

# ==============================================================================
# 1. BACKEND: Cập nhật Logic Thêm Địa Chỉ (AuthController)
# ==============================================================================
echo "⚙️ Cập nhật Backend: Logic thêm địa chỉ..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Http/Controllers/AuthController.php
<?php

namespace Modules\IAM\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Modules\IAM\Models\UserAddress;
use Modules\IAM\Models\Wishlist;
use Modules\Order\Models\Order;

class AuthController extends Controller
{
    // ... (Giữ nguyên các hàm register, login, me, getOrders) ...
    public function register(Request $request) {
        $validator = Validator::make($request->all(), ['email_or_phone' => 'required|string', 'password' => 'required|string|min:6']);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);
        $input = $request->email_or_phone;
        $isEmail = filter_var($input, FILTER_VALIDATE_EMAIL);
        $loginType = $isEmail ? 'email' : 'phone';
        if (User::where($loginType, $input)->exists()) return response()->json(['status' => 422, 'message' => "Tài khoản đã tồn tại."], 422);
        
        $name = $isEmail ? explode('@', $input)[0] : $input;
        $username = $input;
        if (User::where('username', $username)->exists()) $username .= rand(100,999);

        $user = User::create(['name' => $name, 'username' => $username, $loginType => $input, 'password' => Hash::make($request->password), 'membership_tier' => 'member']);
        $token = $user->createToken('auth_token')->plainTextToken;
        return response()->json(['status' => 200, 'message' => 'Đăng ký thành công', 'data' => $user, 'access_token' => $token]);
    }

    public function login(Request $request) {
        $loginType = filter_var($request->email_or_phone, FILTER_VALIDATE_EMAIL) ? 'email' : 'phone';
        if (!Auth::attempt([$loginType => $request->email_or_phone, 'password' => $request->password])) return response()->json(['status' => 401, 'message' => 'Sai tài khoản hoặc mật khẩu.'], 401);
        $user = User::where($loginType, $request->email_or_phone)->firstOrFail();
        $token = $user->createToken('auth_token')->plainTextToken;
        return response()->json(['status' => 200, 'data' => $user, 'access_token' => $token]);
    }

    public function me(Request $request) { return response()->json(['status' => 200, 'data' => $request->user()]); }
    
    public function getOrders(Request $request) {
        $orders = Order::with('items')->where('user_id', $request->user()->id)->orderBy('created_at', 'desc')->get();
        return response()->json(['status' => 200, 'data' => $orders]);
    }

    public function getAddresses(Request $request) {
        $addresses = UserAddress::where('user_id', $request->user()->id)->orderBy('is_default', 'desc')->get();
        return response()->json(['status' => 200, 'data' => $addresses]);
    }

    // UPDATE: Hàm thêm địa chỉ chuẩn
    public function addAddress(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string',
            'phone' => 'required|string',
            'province_id' => 'required',
            'district_id' => 'required',
            'ward_id' => 'required',
            'address' => 'required|string', // Địa chỉ cụ thể (Số nhà)
        ]);

        if ($validator->fails()) return response()->json(['status' => 422, 'message' => 'Dữ liệu không hợp lệ', 'errors' => $validator->errors()], 422);

        $input = $request->all();
        $input['user_id'] = $request->user()->id;
        
        // Nếu set default hoặc chưa có địa chỉ nào -> set default = true
        $count = UserAddress::where('user_id', $request->user()->id)->count();
        if ($request->is_default || $count == 0) {
            UserAddress::where('user_id', $request->user()->id)->update(['is_default' => false]);
            $input['is_default'] = true;
        }

        $addr = UserAddress::create($input);
        return response()->json(['status' => 200, 'message' => 'Thêm địa chỉ thành công', 'data' => $addr]);
    }

    public function getWishlist(Request $request) {
        $list = Wishlist::with('product')->where('user_id', $request->user()->id)->get();
        return response()->json(['status' => 200, 'data' => $list]);
    }
}
EOF

# ==============================================================================
# 2. FRONTEND: Cập nhật Profile (Thêm Modal Add Address)
# ==============================================================================
echo "💻 Cập nhật Frontend Profile (Thêm Modal Address)..."
cat << 'EOF' > /var/www/lica-project/apps/user/app/profile/[username]/page.tsx
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
        const headers = { Authorization: \`Bearer \${token}\` };
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        
        const meRes = await axios.get(\`\${apiUrl}/api/v1/profile/me\`, { headers });
        setUser(meRes.data.data);

        if (activeTab === "orders") {
          const orderRes = await axios.get(\`\${apiUrl}/api/v1/profile/orders\`, { headers });
          setOrders(orderRes.data.data);
        }
        if (activeTab === "address") {
          const addrRes = await axios.get(\`\${apiUrl}/api/v1/profile/addresses\`, { headers });
          setAddresses(addrRes.data.data);
          // Load Province luôn để dùng cho modal
          const provRes = await axios.get(\`\${apiUrl}/api/v1/location/provinces\`);
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
    axios.get(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/location/districts/\${newAddr.province}\`).then(res => setDistricts(res.data.data));
  }, [newAddr.province]);

  useEffect(() => {
    if (!newAddr.district) { setWards([]); return; }
    axios.get(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/location/wards/\${newAddr.district}\`).then(res => setWards(res.data.data));
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
        await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/profile/addresses\`, payload, {
            headers: { Authorization: \`Bearer \${token}\` }
        });
        alert("Thêm địa chỉ thành công!");
        setShowModal(false);
        // Reload list
        const addrRes = await axios.get(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/profile/addresses\`, { headers: { Authorization: \`Bearer \${token}\` } });
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
            <button onClick={() => setActiveTab("profile")} className={\`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition \${activeTab === "profile" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}\`}><User size={18} /> Hồ sơ</button>
            <button onClick={() => setActiveTab("orders")} className={\`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition \${activeTab === "orders" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}\`}><Package size={18} /> Đơn hàng</button>
            <button onClick={() => setActiveTab("address")} className={\`w-full flex items-center gap-3 px-4 py-2.5 rounded-lg transition \${activeTab === "address" ? "bg-blue-50 text-blue-600 font-medium" : "text-gray-600 hover:bg-gray-50"}\`}><MapPin size={18} /> Địa chỉ</button>
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
                    {/* Ở đây có thể hiển thị Tên Tỉnh/Huyện nếu muốn join data, hiện tại đang lưu ID */}
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
EOF

# ==============================================================================
# 3. FRONTEND: Cập nhật Checkout (Auto-fill địa chỉ)
# ==============================================================================
echo "💻 Cập nhật Frontend Checkout (Logic Auto-fill Address)..."
cat << 'EOF' > /var/www/lica-project/apps/user/app/order/shipping/page.tsx
"use client";

import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { MapPin, Phone, User, Loader2 } from "lucide-react";

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
        
        // 1. Load Provinces trước
        const provRes = await axios.get(\`\${apiUrl}/api/v1/location/provinces\`);
        setProvinces(provRes.data.data);

        // 2. Check User & Auto fill
        const token = localStorage.getItem("token");
        if (token) {
            try {
                // Lấy thông tin & địa chỉ
                const [meRes, addrRes] = await Promise.all([
                    axios.get(\`\${apiUrl}/api/v1/profile/me\`, { headers: { Authorization: \`Bearer \${token}\` } }),
                    axios.get(\`\${apiUrl}/api/v1/profile/addresses\`, { headers: { Authorization: \`Bearer \${token}\` } })
                ]);

                const user = meRes.data.data;
                const addresses = addrRes.data.data;
                
                // Tìm địa chỉ mặc định
                const defaultAddr = addresses.find((a: any) => a.is_default) || addresses[0];

                // Fill thông tin cá nhân
                setFormData(prev => ({
                    ...prev,
                    customer_name: defaultAddr ? defaultAddr.name : user.name,
                    customer_phone: defaultAddr ? defaultAddr.phone : (user.phone || ""),
                    customer_email: user.email || ""
                }));

                // Fill địa chỉ (Logic quan trọng)
                if (defaultAddr && defaultAddr.province_id) {
                    setAddressData({
                        street: defaultAddr.address,
                        province_code: defaultAddr.province_id,
                        district_code: defaultAddr.district_id,
                        ward_code: defaultAddr.ward_id
                    });

                    // TRIGGER FETCH Quận & Xã ngay lập tức để Select box hiển thị đúng
                    // Vì React state async, nên ta gọi API trực tiếp tại đây luôn
                    const dRes = await axios.get(\`\${apiUrl}/api/v1/location/districts/\${defaultAddr.province_id}\`);
                    setDistricts(dRes.data.data);

                    const wRes = await axios.get(\`\${apiUrl}/api/v1/location/wards/\${defaultAddr.district_id}\`);
                    setWards(wRes.data.data);
                    
                    // Tìm tên để gán vào locationNames (cho việc submit)
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

  // 2. Handle Change Province (User chọn tay)
  useEffect(() => {
    if (!initializing && addressData.province_code) {
        axios.get(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/location/districts/\${addressData.province_code}\`)
             .then(res => setDistricts(res.data.data));
        const p = provinces.find(x => x.code == addressData.province_code);
        if(p) setLocationNames(prev => ({...prev, province: p.name}));
    }
  }, [addressData.province_code, initializing]);

  // 3. Handle Change District
  useEffect(() => {
    if (!initializing && addressData.district_code) {
        axios.get(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/location/wards/\${addressData.district_code}\`)
             .then(res => setWards(res.data.data));
        const d = districts.find(x => x.code == addressData.district_code);
        if(d) setLocationNames(prev => ({...prev, district: d.name}));
    }
  }, [addressData.district_code, initializing]);

  // 4. Handle Change Ward
  useEffect(() => {
    const w = wards.find(x => x.code == addressData.ward_code);
    if(w) setLocationNames(prev => ({...prev, ward: w.name}));
  }, [addressData.ward_code]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    if (!addressData.street || !addressData.province_code) { setError("Vui lòng điền đủ địa chỉ"); setLoading(false); return; }

    try {
      const finalAddress = \`\${addressData.street}, \${locationNames.ward}, \${locationNames.district}, \${locationNames.province}\`;
      const token = localStorage.getItem("token");
      const headers = token ? { Authorization: \`Bearer \${token}\` } : {};
      
      const res = await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/order/checkout\`, {
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
        <div className="bg-blue-600 p-4 text-white font-bold flex gap-2"><MapPin/> Thông tin giao hàng</div>
        <div className="p-6 grid md:grid-cols-3 gap-8">
            <form onSubmit={handleSubmit} className="md:col-span-2 space-y-4">
                <div className="grid grid-cols-2 gap-4">
                    <div><label className="text-sm font-medium">Họ tên</label><input className="w-full border rounded p-2" value={formData.customer_name} onChange={e => setFormData({...formData, customer_name: e.target.value})} required /></div>
                    <div><label className="text-sm font-medium">SĐT</label><input className="w-full border rounded p-2" value={formData.customer_phone} onChange={e => setFormData({...formData, customer_phone: e.target.value})} required /></div>
                </div>
                <div className="bg-gray-50 p-4 rounded border">
                    <h3 className="text-sm font-bold mb-2">Địa chỉ</h3>
                    <div className="grid grid-cols-3 gap-2 mb-3">
                        <select className="border rounded p-2 text-sm" value={addressData.province_code} onChange={e => setAddressData({...addressData, province_code: e.target.value, district_code: '', ward_code: ''})}>
                            <option value="">Tỉnh/TP</option>
                            {provinces.map(p => <option key={p.code} value={p.code}>{p.name}</option>)}
                        </select>
                        <select className="border rounded p-2 text-sm" value={addressData.district_code} onChange={e => setAddressData({...addressData, district_code: e.target.value, ward_code: ''})}>
                            <option value="">Quận/Huyện</option>
                            {districts.map(d => <option key={d.code} value={d.code}>{d.name}</option>)}
                        </select>
                        <select className="border rounded p-2 text-sm" value={addressData.ward_code} onChange={e => setAddressData({...addressData, ward_code: e.target.value})}>
                            <option value="">Phường/Xã</option>
                            {wards.map(w => <option key={w.code} value={w.code}>{w.name}</option>)}
                        </select>
                    </div>
                    <input className="w-full border rounded p-2 text-sm" placeholder="Số nhà, đường..." value={addressData.street} onChange={e => setAddressData({...addressData, street: e.target.value})} required />
                </div>
                <button type="submit" disabled={loading} className="w-full bg-red-600 text-white font-bold py-3 rounded hover:bg-red-700">{loading ? "Đang xử lý..." : "ĐẶT HÀNG NGAY"}</button>
            </form>
            <div className="space-y-4">
                <div className="bg-gray-50 p-4 rounded border">
                    <h3 className="font-bold border-b pb-2 mb-2">Đơn hàng</h3>
                    {cartItems.map((i, idx) => <div key={idx} className="flex justify-between text-sm mb-2"><span>{i.name} x{i.quantity}</span><span className="font-medium">{new Intl.NumberFormat('vi-VN').format(i.price)}đ</span></div>)}
                    <div className="border-t pt-2 mt-2 flex justify-between font-bold text-red-600"><span>Tổng</span><span>{new Intl.NumberFormat('vi-VN').format(totalAmount)}đ</span></div>
                </div>
            </div>
        </div>
      </div>
    </div>
  );
}
EOF

echo "🔄 Build lại User App..."
cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Hoàn tất! Vào Profile thêm địa chỉ -> Rồi ra Checkout kiểm tra auto-fill."
