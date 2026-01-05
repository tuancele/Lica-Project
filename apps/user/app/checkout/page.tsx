'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import { useCart } from '@/context/CartContext';
import { LocationService, LocationItem } from '@/services/location.service';
import { OrderService } from '@/services/order.service';
import { getImageUrl } from '@/lib/axios';

export default function CheckoutPage() {
  const { items, total, clearCart } = useCart();
  const router = useRouter();
  
  // Form State
  const [formData, setFormData] = useState({
    name: '', phone: '', email: '', address: '', note: ''
  });
  
  // Location State
  const [provinces, setProvinces] = useState<LocationItem[]>([]);
  const [districts, setDistricts] = useState<LocationItem[]>([]);
  const [wards, setWards] = useState<LocationItem[]>([]);
  
  const [selectedProv, setSelectedProv] = useState<string>('');
  const [selectedDist, setSelectedDist] = useState<string>('');
  const [selectedWard, setSelectedWard] = useState<string>('');
  
  const [loading, setLoading] = useState(false);

  // Load Provinces on mount
  useEffect(() => {
    LocationService.getProvinces().then(setProvinces);
  }, []);

  // Load Districts when Province changes
  useEffect(() => {
    if (selectedProv) {
        LocationService.getDistricts(selectedProv).then(setDistricts);
        setWards([]);
        setSelectedDist('');
        setSelectedWard('');
    }
  }, [selectedProv]);

  // Load Wards when District changes
  useEffect(() => {
    if (selectedDist) {
        LocationService.getWards(selectedDist).then(setWards);
        setSelectedWard('');
    }
  }, [selectedDist]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedProv || !selectedDist || !selectedWard) {
        alert("Vui lòng chọn đầy đủ địa chỉ giao hàng!");
        return;
    }
    
    setLoading(true);
    try {
        const payload = {
            customer_name: formData.name,
            customer_phone: formData.phone,
            customer_email: formData.email,
            shipping_address: formData.address,
            province_id: selectedProv,
            district_id: selectedDist,
            ward_id: selectedWard,
            payment_method: 'cod', // Mặc định COD cho đơn giản
            items: items.map(i => ({
                product_id: i.id,
                quantity: i.quantity,
                price: i.sale_price || i.price
            })),
            note: formData.note
        };

        const res = await OrderService.checkout(payload);
        if (res && res.hash_id) {
            clearCart();
            router.push(`/order/success/${res.hash_id}`);
        } else {
            alert('Có lỗi xảy ra, vui lòng thử lại.');
        }
    } catch (error) {
        console.error(error);
        alert('Đặt hàng thất bại. Vui lòng kiểm tra lại thông tin.');
    } finally {
        setLoading(false);
    }
  };

  if (items.length === 0) return <div className="p-10 text-center">Giỏ hàng trống</div>;

  return (
    <div className="bg-gray-50 min-h-screen font-sans">
      <Header />
      <div className="container-custom py-8">
        <h1 className="text-xl font-bold mb-6 text-gray-800 uppercase border-l-4 border-lica-primary pl-3">Thông tin giao hàng</h1>
        
        <form onSubmit={handleSubmit} className="grid grid-cols-1 lg:grid-cols-12 gap-8">
            {/* Form Info */}
            <div className="lg:col-span-7 space-y-6">
                <div className="bg-white p-6 rounded-lg shadow-sm">
                    <h3 className="font-bold mb-4">1. Thông tin người nhận</h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                        <input required placeholder="Họ và tên" className="border p-3 rounded text-sm focus:border-lica-primary outline-none" 
                            onChange={e => setFormData({...formData, name: e.target.value})} />
                        <input required placeholder="Số điện thoại" className="border p-3 rounded text-sm focus:border-lica-primary outline-none" 
                            onChange={e => setFormData({...formData, phone: e.target.value})} />
                    </div>
                    <input type="email" placeholder="Email (Không bắt buộc)" className="border p-3 rounded text-sm w-full mb-4 focus:border-lica-primary outline-none" 
                        onChange={e => setFormData({...formData, email: e.target.value})} />
                    
                    <h3 className="font-bold mb-4 mt-6">2. Địa chỉ nhận hàng</h3>
                    <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                        <select className="border p-3 rounded text-sm outline-none" value={selectedProv} onChange={e => setSelectedProv(e.target.value)}>
                            <option value="">-- Tỉnh / Thành --</option>
                            {provinces.map(p => <option key={p.code} value={p.code}>{p.name_with_type}</option>)}
                        </select>
                        <select className="border p-3 rounded text-sm outline-none" value={selectedDist} onChange={e => setSelectedDist(e.target.value)} disabled={!selectedProv}>
                            <option value="">-- Quận / Huyện --</option>
                            {districts.map(d => <option key={d.code} value={d.code}>{d.name_with_type}</option>)}
                        </select>
                        <select className="border p-3 rounded text-sm outline-none" value={selectedWard} onChange={e => setSelectedWard(e.target.value)} disabled={!selectedDist}>
                            <option value="">-- Phường / Xã --</option>
                            {wards.map(w => <option key={w.code} value={w.code}>{w.name_with_type}</option>)}
                        </select>
                    </div>
                    <input required placeholder="Số nhà, tên đường..." className="border p-3 rounded text-sm w-full focus:border-lica-primary outline-none" 
                        onChange={e => setFormData({...formData, address: e.target.value})} />
                        
                    <textarea placeholder="Ghi chú đơn hàng (nếu có)" className="border p-3 rounded text-sm w-full mt-4 h-24 focus:border-lica-primary outline-none"
                        onChange={e => setFormData({...formData, note: e.target.value})}></textarea>
                </div>
            </div>

            {/* Order Summary */}
            <div className="lg:col-span-5">
                <div className="bg-white p-6 rounded-lg shadow-sm sticky top-24">
                    <h3 className="font-bold mb-4">Đơn hàng ({items.length} sản phẩm)</h3>
                    <div className="space-y-3 max-h-[300px] overflow-y-auto mb-4 custom-scrollbar">
                        {items.map(item => {
                             let img = null;
                             try { img = Array.isArray(item.images) ? item.images[0] : JSON.parse(item.images as string)[0]; } catch { img = item.images; }
                             return (
                                <div key={item.id} className="flex gap-3 text-sm">
                                    <div className="w-12 h-12 flex-shrink-0 border rounded overflow-hidden">
                                        <img src={getImageUrl(img)} className="w-full h-full object-cover" />
                                    </div>
                                    <div className="flex-1">
                                        <p className="line-clamp-1">{item.name}</p>
                                        <div className="flex justify-between mt-1 text-xs text-gray-500">
                                            <span>x {item.quantity}</span>
                                            <span className="font-bold text-gray-800">{(item.sale_price || item.price).toLocaleString('vi-VN')}₫</span>
                                        </div>
                                    </div>
                                </div>
                             );
                        })}
                    </div>
                    
                    <div className="border-t border-gray-100 pt-4 space-y-2 text-sm">
                        <div className="flex justify-between">
                            <span className="text-gray-600">Tạm tính:</span>
                            <span className="font-bold">{total.toLocaleString('vi-VN')} ₫</span>
                        </div>
                        <div className="flex justify-between">
                            <span className="text-gray-600">Phí vận chuyển:</span>
                            <span className="text-green-600 font-medium">Miễn phí</span>
                        </div>
                    </div>
                    
                    <div className="border-t border-gray-100 pt-4 mt-4">
                        <div className="flex justify-between items-end">
                            <span className="font-bold text-gray-800">Tổng thanh toán:</span>
                            <span className="text-2xl font-bold text-lica-red">{total.toLocaleString('vi-VN')} ₫</span>
                        </div>
                        <button disabled={loading} className="w-full mt-6 bg-lica-red text-white py-3 rounded font-bold uppercase hover:bg-red-700 disabled:opacity-50 transition-colors">
                            {loading ? 'Đang xử lý...' : 'Đặt hàng ngay'}
                        </button>
                    </div>
                </div>
            </div>
        </form>
      </div>
      <Footer />
    </div>
  );
}
