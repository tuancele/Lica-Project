#!/bin/bash

echo "🚀 Đang nâng cấp trang Thanh toán với bộ chọn Địa điểm..."

cat << 'EOF' > /var/www/lica-project/apps/user/app/order/shipping/page.tsx
"use client";

import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { MapPin, Phone, User, Loader2 } from "lucide-react";

// Định nghĩa kiểu dữ liệu cho Địa chính
interface Location {
  code: string;
  name: string;
}

export default function ShippingPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [initializing, setInitializing] = useState(true);
  const [error, setError] = useState("");

  // Dữ liệu danh sách (để đổ vào Select)
  const [provinces, setProvinces] = useState<Location[]>([]);
  const [districts, setDistricts] = useState<Location[]>([]);
  const [wards, setWards] = useState<Location[]>([]);

  // State form nhập liệu
  const [formData, setFormData] = useState({
    customer_name: "",
    customer_phone: "",
    customer_email: "",
    payment_method: "cash_on_delivery",
    note: ""
  });

  // State riêng cho địa chỉ (tách biệt để xử lý logic select)
  const [addressData, setAddressData] = useState({
    street: "", // Số nhà, tên đường
    province_code: "",
    district_code: "",
    ward_code: "",
    full_address: "" // Dùng để hiển thị hoặc debug
  });

  // Tên hiển thị của địa chỉ đã chọn (để ghép chuỗi gửi về BE)
  const [locationNames, setLocationNames] = useState({
    province: "",
    district: "",
    ward: ""
  });

  // Giả lập giỏ hàng (Thực tế lấy từ Context/LocalStorage)
  const cartItems = [
    { product_id: 1, quantity: 1, name: "Sản phẩm Demo", price: 500000 }
  ];
  const totalAmount = cartItems.reduce((acc, item) => acc + (item.price * item.quantity), 0);

  // 1. Load Tỉnh/Thành phố khi vào trang
  useEffect(() => {
    const initData = async () => {
      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.lica.vn";
        
        // Load Provinces
        const provRes = await axios.get(`${apiUrl}/api/v1/location/provinces`);
        setProvinces(provRes.data.data);

        // Kiểm tra User đã đăng nhập chưa để pre-fill
        const token = localStorage.getItem("token");
        if (token) {
            try {
                // Lấy thông tin user cơ bản
                const meRes = await axios.get(`${apiUrl}/api/v1/profile/me`, {
                    headers: { Authorization: `Bearer ${token}` }
                });
                const user = meRes.data.data;
                
                // Điền thông tin cơ bản
                setFormData(prev => ({
                    ...prev,
                    customer_name: user.name,
                    customer_phone: user.phone || "",
                    customer_email: user.email || ""
                }));

                // Lấy danh sách địa chỉ đã lưu
                const addrRes = await axios.get(`${apiUrl}/api/v1/profile/addresses`, {
                    headers: { Authorization: `Bearer ${token}` }
                });
                
                // Nếu có địa chỉ mặc định, thử điền vào (Logic này cần địa chỉ lưu có structure, 
                // hiện tại ta tạm thời để user tự chọn lại nếu địa chỉ cũ lưu dạng text thuần,
                // hoặc nâng cấp sau này để lưu ID tỉnh thành vào DB)
                const defaultAddr = addrRes.data.data.find((a: any) => a.is_default);
                if (defaultAddr && defaultAddr.province_id) {
                     // Nếu sau này bạn lưu province_id vào DB thì code pre-fill sẽ nằm ở đây
                     // Hiện tại để user tự chọn cho chính xác với data mới
                }

            } catch (err) {
                console.log("Khách chưa đăng nhập hoặc token hết hạn");
            }
        }
      } catch (err) {
        console.error("Lỗi tải dữ liệu", err);
      } finally {
        setInitializing(false);
      }
    };
    initData();
  }, []);

  // 2. Load Quận/Huyện khi chọn Tỉnh
  useEffect(() => {
    if (!addressData.province_code) {
        setDistricts([]);
        setWards([]);
        return;
    }
    const fetchDistricts = async () => {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.lica.vn";
        const res = await axios.get(`${apiUrl}/api/v1/location/districts/${addressData.province_code}`);
        setDistricts(res.data.data);
        setAddressData(prev => ({ ...prev, district_code: "", ward_code: "" })); // Reset con
    };
    fetchDistricts();
    
    // Lưu tên tỉnh để ghép chuỗi
    const p = provinces.find(x => x.code == addressData.province_code);
    if(p) setLocationNames(prev => ({...prev, province: p.name, district: "", ward: ""}));

  }, [addressData.province_code]);

  // 3. Load Xã/Phường khi chọn Quận
  useEffect(() => {
    if (!addressData.district_code) {
        setWards([]);
        return;
    }
    const fetchWards = async () => {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.lica.vn";
        const res = await axios.get(`${apiUrl}/api/v1/location/wards/${addressData.district_code}`);
        setWards(res.data.data);
        setAddressData(prev => ({ ...prev, ward_code: "" })); // Reset con
    };
    fetchWards();

    // Lưu tên huyện
    const d = districts.find(x => x.code == addressData.district_code);
    if(d) setLocationNames(prev => ({...prev, district: d.name, ward: ""}));

  }, [addressData.district_code]);

  // Lưu tên xã khi chọn
  useEffect(() => {
    const w = wards.find(x => x.code == addressData.ward_code);
    if(w) setLocationNames(prev => ({...prev, ward: w.name}));
  }, [addressData.ward_code]);


  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);

    // Validate địa chỉ
    if (!addressData.street || !addressData.province_code || !addressData.district_code || !addressData.ward_code) {
        setError("Vui lòng điền đầy đủ địa chỉ giao hàng (Số nhà, Tỉnh, Huyện, Xã)");
        setLoading(false);
        return;
    }

    try {
      // Ghép địa chỉ thành chuỗi đầy đủ: "Số 10, Xã A, Huyện B, Tỉnh C"
      const finalAddress = `${addressData.street}, ${locationNames.ward}, ${locationNames.district}, ${locationNames.province}`;

      const payload = {
        ...formData,
        shipping_address: finalAddress, // Backend nhận chuỗi này
        items: cartItems.map(item => ({ product_id: item.product_id, quantity: item.quantity }))
      };

      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.lica.vn";
      const res = await axios.post(`${apiUrl}/api/v1/order/checkout`, payload);

      if (res.data.status === 200) {
        const redirectUrl = res.data.data.redirect_url;
        router.push(redirectUrl);
      }
    } catch (err: any) {
      console.error(err);
      setError(err.response?.data?.message || "Có lỗi xảy ra khi đặt hàng.");
    } finally {
      setLoading(false);
    }
  };

  if (initializing) return <div className="min-h-screen flex justify-center items-center"><Loader2 className="animate-spin text-blue-600"/></div>;

  return (
    <div className="min-h-screen bg-gray-50 p-4 font-sans">
      <div className="max-w-4xl mx-auto">
        <div className="bg-white shadow-sm rounded-xl overflow-hidden border border-gray-100">
          <div className="bg-gradient-to-r from-blue-600 to-blue-500 p-4 text-white flex justify-between items-center">
            <h1 className="text-xl font-bold flex items-center gap-2">
                <MapPin size={20}/> Thông tin giao hàng
            </h1>
          </div>
          
          <div className="p-6 grid md:grid-cols-3 gap-8">
            {/* Cột trái: Form nhập liệu (Chiếm 2 phần) */}
            <form onSubmit={handleSubmit} className="md:col-span-2 space-y-5">
              
              {/* Thông tin cá nhân */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Họ và tên *</label>
                    <div className="relative">
                        <User size={18} className="absolute left-3 top-2.5 text-gray-400"/>
                        <input type="text" name="customer_name" required className="w-full border rounded-lg pl-10 pr-3 py-2 outline-none focus:ring-2 focus:ring-blue-500" 
                            placeholder="Nguyễn Văn A" value={formData.customer_name} onChange={handleChange} />
                    </div>
                  </div>
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">Số điện thoại *</label>
                    <div className="relative">
                        <Phone size={18} className="absolute left-3 top-2.5 text-gray-400"/>
                        <input type="tel" name="customer_phone" required className="w-full border rounded-lg pl-10 pr-3 py-2 outline-none focus:ring-2 focus:ring-blue-500" 
                            placeholder="09xxxxxx" value={formData.customer_phone} onChange={handleChange} />
                    </div>
                  </div>
              </div>

              {/* Bộ chọn địa chỉ 3 cấp */}
              <div className="bg-gray-50 p-4 rounded-lg border border-gray-200">
                  <h3 className="font-semibold text-gray-800 mb-3 text-sm uppercase">Địa chỉ nhận hàng</h3>
                  
                  <div className="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
                      <div>
                          <label className="block text-xs font-medium text-gray-500 mb-1">Tỉnh / Thành phố *</label>
                          <select 
                            className="w-full border rounded-md px-2 py-2 text-sm outline-none focus:border-blue-500"
                            value={addressData.province_code}
                            onChange={(e) => setAddressData({...addressData, province_code: e.target.value})}
                          >
                              <option value="">-- Chọn Tỉnh --</option>
                              {provinces.map(p => <option key={p.code} value={p.code}>{p.name}</option>)}
                          </select>
                      </div>
                      <div>
                          <label className="block text-xs font-medium text-gray-500 mb-1">Quận / Huyện *</label>
                          <select 
                            className="w-full border rounded-md px-2 py-2 text-sm outline-none focus:border-blue-500"
                            value={addressData.district_code}
                            onChange={(e) => setAddressData({...addressData, district_code: e.target.value})}
                            disabled={!addressData.province_code}
                          >
                              <option value="">-- Chọn Quận --</option>
                              {districts.map(d => <option key={d.code} value={d.code}>{d.name}</option>)}
                          </select>
                      </div>
                      <div>
                          <label className="block text-xs font-medium text-gray-500 mb-1">Phường / Xã *</label>
                          <select 
                            className="w-full border rounded-md px-2 py-2 text-sm outline-none focus:border-blue-500"
                            value={addressData.ward_code}
                            onChange={(e) => setAddressData({...addressData, ward_code: e.target.value})}
                            disabled={!addressData.district_code}
                          >
                              <option value="">-- Chọn Xã --</option>
                              {wards.map(w => <option key={w.code} value={w.code}>{w.name}</option>)}
                          </select>
                      </div>
                  </div>

                  <div>
                    <label className="block text-xs font-medium text-gray-500 mb-1">Địa chỉ cụ thể (Số nhà, đường...) *</label>
                    <input type="text" className="w-full border rounded-md px-3 py-2 text-sm outline-none focus:border-blue-500" 
                        placeholder="VD: Số 1 Đại Cồ Việt"
                        value={addressData.street}
                        onChange={(e) => setAddressData({...addressData, street: e.target.value})}
                    />
                  </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Ghi chú (Tùy chọn)</label>
                <textarea name="note" rows={2} className="w-full border rounded-lg px-3 py-2 outline-none focus:ring-2 focus:ring-blue-500" 
                    placeholder="VD: Giao giờ hành chính..." onChange={handleChange}></textarea>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Phương thức thanh toán</label>
                <div className="grid grid-cols-2 gap-3">
                    <label className={`border rounded-lg p-3 flex items-center gap-2 cursor-pointer transition ${formData.payment_method === 'cash_on_delivery' ? 'border-blue-600 bg-blue-50' : 'hover:border-gray-400'}`}>
                        <input type="radio" name="payment_method" value="cash_on_delivery" checked={formData.payment_method === 'cash_on_delivery'} onChange={handleChange} />
                        <span className="text-sm font-medium">COD (Tiền mặt)</span>
                    </label>
                    <label className={`border rounded-lg p-3 flex items-center gap-2 cursor-pointer transition ${formData.payment_method === 'banking' ? 'border-blue-600 bg-blue-50' : 'hover:border-gray-400'}`}>
                        <input type="radio" name="payment_method" value="banking" checked={formData.payment_method === 'banking'} onChange={handleChange} />
                        <span className="text-sm font-medium">Chuyển khoản</span>
                    </label>
                </div>
              </div>

              {error && <div className="p-3 bg-red-50 text-red-600 text-sm rounded-lg border border-red-200 flex items-center gap-2"><div className="w-2 h-2 bg-red-600 rounded-full"></div>{error}</div>}

              <button type="submit" disabled={loading} className="w-full bg-red-600 text-white font-bold py-3.5 rounded-lg hover:bg-red-700 transition disabled:opacity-70 shadow-lg shadow-red-200">
                {loading ? "Đang xử lý đơn hàng..." : `ĐẶT HÀNG NGAY (${new Intl.NumberFormat('vi-VN').format(totalAmount)}đ)`}
              </button>
            </form>

            {/* Cột phải: Tóm tắt đơn hàng */}
            <div className="h-fit space-y-4">
                <div className="bg-gray-50 p-4 rounded-lg border border-gray-200">
                    <h2 className="font-bold text-gray-800 border-b pb-2 mb-3 text-sm uppercase">Đơn hàng của bạn</h2>
                    <div className="space-y-3">
                    {cartItems.map((item, idx) => (
                        <div key={idx} className="flex justify-between text-sm group">
                            <div>
                                <div className="font-medium group-hover:text-blue-600 transition">{item.name}</div>
                                <div className="text-gray-500 text-xs">SL: x{item.quantity}</div>
                            </div>
                            <span className="font-medium">{new Intl.NumberFormat('vi-VN').format(item.price * item.quantity)}đ</span>
                        </div>
                    ))}
                    </div>
                    <div className="border-t border-dashed border-gray-300 mt-4 pt-4 space-y-2">
                        <div className="flex justify-between text-sm text-gray-600">
                            <span>Tạm tính</span>
                            <span>{new Intl.NumberFormat('vi-VN').format(totalAmount)}đ</span>
                        </div>
                        <div className="flex justify-between text-sm text-gray-600">
                            <span>Phí vận chuyển</span>
                            <span className="text-green-600 font-medium">Miễn phí</span>
                        </div>
                    </div>
                    <div className="border-t mt-3 pt-3 flex justify-between font-bold text-lg text-red-600">
                    <span>Tổng cộng</span>
                    <span>{new Intl.NumberFormat('vi-VN').format(totalAmount)}đ</span>
                    </div>
                </div>
                
                <div className="text-xs text-gray-500 text-center px-4">
                    Bằng việc tiến hành đặt hàng, bạn đồng ý với <a href="#" className="underline hover:text-blue-600">điều khoản dịch vụ</a> của Lica.vn
                </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

echo "🔄 Đang build lại User App..."
cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Đã cập nhật xong! Hãy thử vào trang Đặt hàng để chọn địa chỉ."
