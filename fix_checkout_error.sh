#!/bin/bash

echo "🛠️ Đang sửa lỗi Đặt hàng (Checkout 500 Error)..."

# ==============================================================================
# 1. BACKEND: Cập nhật OrderController (Log lỗi + Lưu User ID)
# ==============================================================================
echo "⚙️ Cập nhật Backend OrderController..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/Order/app/Http/Controllers/OrderController.php
<?php

namespace Modules\Order\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Order\Models\Order;
use Modules\Order\Models\OrderItem;
use Modules\Product\Models\Product;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Auth;

class OrderController extends Controller
{
    // ================= CLIENT API =================

    public function checkout(Request $request)
    {
        // 1. Log request để debug
        Log::info('Checkout Request Data:', $request->all());

        $validator = Validator::make($request->all(), [
            'customer_name' => 'required|string',
            'customer_phone' => 'required|string',
            'shipping_address' => 'required|string',
            'items' => 'required|array|min:1',
        ]);

        if ($validator->fails()) {
            Log::warning('Checkout Validation Failed:', $validator->errors()->toArray());
            return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);
        }

        DB::beginTransaction();
        try {
            $input = $request->all();
            
            // 2. Lấy User ID nếu có (Dùng Guard Sanctum)
            $userId = null;
            if (auth('sanctum')->check()) {
                $userId = auth('sanctum')->id();
            }

            $totalAmount = 0;
            $orderItemsData = [];

            foreach ($input['items'] as $item) {
                // Lock row để tránh race condition
                $product = Product::lockForUpdate()->find($item['product_id']);
                
                if (!$product) {
                    DB::rollBack();
                    return response()->json(['status' => 400, 'message' => "Sản phẩm ID {$item['product_id']} không tồn tại."], 400);
                }

                if ($product->stock_quantity < $item['quantity']) {
                    DB::rollBack();
                    return response()->json(['status' => 400, 'message' => "Sản phẩm {$product->name} không đủ hàng tồn kho."], 400);
                }

                $price = $product->sale_price > 0 ? $product->sale_price : $product->price;
                $lineTotal = $price * $item['quantity'];
                $totalAmount += $lineTotal;

                $orderItemsData[] = [
                    'product_id' => $product->id,
                    'product_name' => $product->name,
                    'sku' => $product->sku,
                    'quantity' => $item['quantity'],
                    'price' => $price,
                    'total' => $lineTotal,
                    'options' => json_encode($item['options'] ?? [])
                ];

                // Trừ tồn kho
                $product->decrement('stock_quantity', $item['quantity']);
            }

            // 3. Tạo Order (Thêm user_id)
            $order = Order::create([
                'user_id' => $userId, // <--- QUAN TRỌNG: Lưu ID người dùng
                'customer_name' => $input['customer_name'],
                'customer_phone' => $input['customer_phone'],
                'customer_email' => $input['customer_email'] ?? null,
                'shipping_address' => $input['shipping_address'],
                'note' => $input['note'] ?? null,
                'total_amount' => $totalAmount,
                'payment_method' => $input['payment_method'] ?? 'cod',
                'status' => 'pending'
            ]);

            foreach ($orderItemsData as $data) {
                $order->items()->create($data);
            }

            DB::commit();

            return response()->json([
                'status' => 200,
                'message' => 'Đặt hàng thành công',
                'data' => [
                    'order_code' => $order->code,
                    'hash_id' => $order->hash_id,
                    'redirect_url' => "/order/success/{$order->hash_id}"
                ]
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            // Ghi log lỗi chi tiết ra file storage/logs/laravel.log
            Log::error('Checkout Error 500: ' . $e->getMessage());
            Log::error($e->getTraceAsString());
            
            return response()->json(['status' => 500, 'message' => 'Lỗi hệ thống: ' . $e->getMessage()], 500);
        }
    }

    public function getOrderByHash($hash)
    {
        $order = Order::with('items')->where('hash_id', $hash)->first();
        return $order ? response()->json(['status' => 200, 'data' => $order]) : response()->json(['status' => 404], 404);
    }

    // ================= ADMIN API =================

    public function index(Request $request)
    {
        $query = Order::with('items.product')->orderBy('created_at', 'desc');

        if ($request->has('status') && $request->status !== 'all') {
            $query->where('status', $request->status);
        }

        if ($request->has('q') && !empty($request->q)) {
            $q = $request->q;
            $query->where(function($sub) use ($q) {
                $sub->where('code', 'like', "%{$q}%")
                    ->orWhere('customer_name', 'like', "%{$q}%")
                    ->orWhere('customer_phone', 'like', "%{$q}%");
            });
        }

        $data = $query->paginate($request->get('limit', 10));
        
        $counts = Order::select('status', DB::raw('count(*) as total'))
            ->groupBy('status')
            ->pluck('total', 'status')
            ->toArray();

        return response()->json([
            'status' => 200,
            'data' => $data,
            'counts' => $counts
        ]);
    }

    public function show($id)
    {
        $query = Order::with('items.product');
        if (is_numeric($id)) {
            $order = $query->find($id);
            if (!$order) $order = $query->where('code', $id)->first();
        } else {
            $order = $query->where('code', $id)->first();
        }

        return $order 
            ? response()->json(['status' => 200, 'data' => $order]) 
            : response()->json(['message' => 'Không tìm thấy đơn hàng'], 404);
    }

    public function updateStatus(Request $request, $id)
    {
        $order = is_numeric($id) ? Order::find($id) : Order::where('code', $id)->first();
        if (!$order) return response()->json(['message' => 'Not found'], 404);

        $newStatus = $request->status;
        $order->status = $newStatus;
        if ($newStatus === 'completed') $order->payment_status = 'paid';
        $order->save();

        return response()->json(['status' => 200, 'message' => 'Cập nhật trạng thái thành công', 'data' => $order]);
    }
}
EOF

# ==============================================================================
# 2. FRONTEND: Cập nhật Shipping Page (Gửi kèm Token)
# ==============================================================================
echo "💻 Cập nhật Frontend Shipping (Gửi Token khi checkout)..."
cat << 'EOF' > /var/www/lica-project/apps/user/app/order/shipping/page.tsx
"use client";

import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { MapPin, Phone, User, Loader2 } from "lucide-react";

interface Location {
  code: string;
  name: string;
}

export default function ShippingPage() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [initializing, setInitializing] = useState(true);
  const [error, setError] = useState("");

  const [provinces, setProvinces] = useState<Location[]>([]);
  const [districts, setDistricts] = useState<Location[]>([]);
  const [wards, setWards] = useState<Location[]>([]);

  const [formData, setFormData] = useState({
    customer_name: "",
    customer_phone: "",
    customer_email: "",
    payment_method: "cash_on_delivery",
    note: ""
  });

  const [addressData, setAddressData] = useState({
    street: "",
    province_code: "",
    district_code: "",
    ward_code: "",
    full_address: ""
  });

  const [locationNames, setLocationNames] = useState({
    province: "",
    district: "",
    ward: ""
  });

  // Giả lập giỏ hàng
  const cartItems = [
    { product_id: 1, quantity: 1, name: "Sản phẩm Demo", price: 500000 }
  ];
  const totalAmount = cartItems.reduce((acc, item) => acc + (item.price * item.quantity), 0);

  useEffect(() => {
    const initData = async () => {
      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.lica.vn";
        const provRes = await axios.get(`${apiUrl}/api/v1/location/provinces`);
        setProvinces(provRes.data.data);

        const token = localStorage.getItem("token");
        if (token) {
            try {
                const meRes = await axios.get(`${apiUrl}/api/v1/profile/me`, {
                    headers: { Authorization: `Bearer ${token}` }
                });
                const user = meRes.data.data;
                setFormData(prev => ({
                    ...prev,
                    customer_name: user.name,
                    customer_phone: user.phone || "",
                    customer_email: user.email || ""
                }));
            } catch (err) {
                console.log("Token hết hạn");
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
        setAddressData(prev => ({ ...prev, district_code: "", ward_code: "" }));
    };
    fetchDistricts();
    const p = provinces.find(x => x.code == addressData.province_code);
    if(p) setLocationNames(prev => ({...prev, province: p.name, district: "", ward: ""}));

  }, [addressData.province_code]);

  useEffect(() => {
    if (!addressData.district_code) {
        setWards([]);
        return;
    }
    const fetchWards = async () => {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.lica.vn";
        const res = await axios.get(`${apiUrl}/api/v1/location/wards/${addressData.district_code}`);
        setWards(res.data.data);
        setAddressData(prev => ({ ...prev, ward_code: "" }));
    };
    fetchWards();
    const d = districts.find(x => x.code == addressData.district_code);
    if(d) setLocationNames(prev => ({...prev, district: d.name, ward: ""}));

  }, [addressData.district_code]);

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

    if (!addressData.street || !addressData.province_code || !addressData.district_code || !addressData.ward_code) {
        setError("Vui lòng điền đầy đủ địa chỉ giao hàng (Số nhà, Tỉnh, Huyện, Xã)");
        setLoading(false);
        return;
    }

    try {
      const finalAddress = `${addressData.street}, ${locationNames.ward}, ${locationNames.district}, ${locationNames.province}`;
      const payload = {
        ...formData,
        shipping_address: finalAddress,
        items: cartItems.map(item => ({ product_id: item.product_id, quantity: item.quantity }))
      };

      const apiUrl = process.env.NEXT_PUBLIC_API_URL || "https://api.lica.vn";
      
      // Lấy token để gửi kèm (Nếu có) -> Quan trọng để Backend nhận diện User
      const token = localStorage.getItem("token");
      const headers = token ? { Authorization: `Bearer ${token}` } : {};

      const res = await axios.post(`${apiUrl}/api/v1/order/checkout`, payload, { headers });

      if (res.data.status === 200) {
        router.push(res.data.data.redirect_url);
      }
    } catch (err: any) {
      console.error(err);
      setError(err.response?.data?.message || "Có lỗi xảy ra khi đặt hàng. Vui lòng thử lại.");
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
            <form onSubmit={handleSubmit} className="md:col-span-2 space-y-5">
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
                    <label className="block text-xs font-medium text-gray-500 mb-1">Địa chỉ cụ thể *</label>
                    <input type="text" className="w-full border rounded-md px-3 py-2 text-sm outline-none focus:border-blue-500" 
                        placeholder="VD: Số 1 Đại Cồ Việt"
                        value={addressData.street}
                        onChange={(e) => setAddressData({...addressData, street: e.target.value})}
                    />
                  </div>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Ghi chú</label>
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

              {error && <div className="p-3 bg-red-50 text-red-600 text-sm rounded-lg border border-red-200">{error}</div>}

              <button type="submit" disabled={loading} className="w-full bg-red-600 text-white font-bold py-3.5 rounded-lg hover:bg-red-700 transition disabled:opacity-70 shadow-lg shadow-red-200">
                {loading ? "Đang xử lý đơn hàng..." : `ĐẶT HÀNG NGAY (${new Intl.NumberFormat('vi-VN').format(totalAmount)}đ)`}
              </button>
            </form>

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
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# 3. SET PERMISSION LOGS & BUILD
# ==============================================================================
echo "🔑 Cấp quyền ghi log cho Backend (để debug nếu còn lỗi)..."
chown -R www-data:www-data /var/www/lica-project/backend/storage
chmod -R 777 /var/www/lica-project/backend/storage

echo "🔄 Build lại Frontend User..."
cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Đã sửa lỗi! Hãy thử đặt hàng lại. Nếu lỗi 500, xem log tại: /var/www/lica-project/backend/storage/logs/laravel.log"
