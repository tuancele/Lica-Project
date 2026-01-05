'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Trash2, Plus, Save, Calendar, Tag, Zap } from 'lucide-react';
import axios from 'axios';
import ProductSelector from './ProductSelector';

interface PromotionFormProps {
    initialData?: any;
    promotionId?: number | string;
    defaultType?: 'promotion' | 'flash_sale'; // Prop mới
}

export default function PromotionForm({ initialData, promotionId, defaultType = 'promotion' }: PromotionFormProps) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [showSelector, setShowSelector] = useState(false);

  const [formData, setFormData] = useState({
    name: initialData?.name || '',
    start_at: initialData?.start_at ? initialData.start_at.slice(0, 16) : '',
    end_at: initialData?.end_at ? initialData.end_at.slice(0, 16) : '',
    type: initialData?.type || defaultType, // Set type
  });

  const [selectedProducts, setSelectedProducts] = useState<any[]>(
    initialData?.items?.map((item: any) => ({
        product_id: item.product_id,
        product: item.product,
        promotion_price: item.promotion_price,
        stock_limit: item.stock_limit
    })) || []
  );

  const handleSelectProducts = (newProducts: any[]) => {
    const currentIds = selectedProducts.map(p => p.product_id);
    const uniqueNew = newProducts.filter(p => !currentIds.includes(p.id));

    const formatted = uniqueNew.map(p => ({
        product_id: p.id,
        product: p,
        promotion_price: p.price,
        stock_limit: '' 
    }));
    setSelectedProducts([...selectedProducts, ...formatted]);
  };

  const removeProduct = (index: number) => {
    const newProducts = [...selectedProducts];
    newProducts.splice(index, 1);
    setSelectedProducts(newProducts);
  };

  const updateProductItem = (index: number, field: string, value: any) => {
    const newProducts = [...selectedProducts];
    newProducts[index][field] = value;
    setSelectedProducts(newProducts);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (selectedProducts.length === 0) {
        alert("Vui lòng chọn ít nhất 1 sản phẩm!");
        return;
    }

    setLoading(true);
    try {
      const baseURL = process.env.NEXT_PUBLIC_API_URL?.endsWith('/api/v1') 
            ? process.env.NEXT_PUBLIC_API_URL 
            : `${process.env.NEXT_PUBLIC_API_URL}/api/v1`;

      const payload = {
        ...formData,
        products: selectedProducts.map(item => ({
            id: item.product_id,
            promotion_price: Number(item.promotion_price),
            stock_limit: item.stock_limit ? Number(item.stock_limit) : null
        }))
      };

      if (promotionId) {
         await axios.put(`${baseURL}/marketing/promotions/${promotionId}`, payload);
         alert('Cập nhật thành công!');
      } else {
         await axios.post(`${baseURL}/marketing/promotions`, payload);
         alert('Tạo mới thành công!');
      }
      
      // Redirect dựa trên type
      if (formData.type === 'flash_sale') {
          router.push('/marketing/flash-sales');
      } else {
          router.push('/marketing/promotions');
      }
    } catch (error: any) {
      console.error(error);
      alert(error.response?.data?.message || 'Có lỗi xảy ra');
    } finally {
      setLoading(false);
    }
  };

  const getImageUrl = (imgData: any) => {
    if (!imgData) return "https://placehold.co/50x50?text=NoImg";
    try {
        if (typeof imgData === 'string') {
             const parsed = JSON.parse(imgData);
             return Array.isArray(parsed) ? parsed[0] : imgData;
        }
        if (Array.isArray(imgData)) return imgData[0];
    } catch {}
    return imgData;
  };

  const isFlashSale = formData.type === 'flash_sale';

  return (
    <>
      <form onSubmit={handleSubmit} className="space-y-6 max-w-5xl mx-auto pb-20">
        
        <div className={`p-6 rounded-xl shadow-sm border ${isFlashSale ? 'bg-orange-50 border-orange-200' : 'bg-white border-gray-200'}`}>
            <div className="flex items-center gap-2 mb-6 border-b border-gray-200 pb-4">
                {isFlashSale ? <Zap className="text-orange-600" size={24} /> : <Tag className="text-blue-600" size={24} />}
                <h3 className={`font-bold text-lg ${isFlashSale ? 'text-orange-800' : 'text-gray-800'}`}>
                    {isFlashSale ? 'Thông tin Flash Sale' : 'Thông tin Chương trình'}
                </h3>
            </div>
            
            <div className="grid grid-cols-1 gap-6">
                <div>
                    <label className="block text-sm font-semibold text-gray-700 mb-2">Tên chương trình <span className="text-red-500">*</span></label>
                    <input required type="text" className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm focus:ring-2 focus:ring-blue-100 focus:border-blue-500 outline-none transition" 
                        value={formData.name} onChange={e => setFormData({...formData, name: e.target.value})} 
                        placeholder={isFlashSale ? "VD: Flash Sale Giờ Vàng 12h" : "VD: Sale Tháng 9"} />
                </div>
                
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <div>
                        <label className="block text-sm font-semibold text-gray-700 mb-2 flex items-center gap-2">
                            <Calendar size={16}/> Thời gian bắt đầu <span className="text-red-500">*</span>
                        </label>
                        <input required type="datetime-local" className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm" 
                            value={formData.start_at} onChange={e => setFormData({...formData, start_at: e.target.value})} />
                    </div>
                    <div>
                        <label className="block text-sm font-semibold text-gray-700 mb-2 flex items-center gap-2">
                            <Calendar size={16}/> Thời gian kết thúc <span className="text-red-500">*</span>
                        </label>
                        <input required type="datetime-local" className="w-full border border-gray-300 rounded-lg px-4 py-2.5 text-sm" 
                            value={formData.end_at} onChange={e => setFormData({...formData, end_at: e.target.value})} />
                    </div>
                </div>
            </div>
        </div>

        <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
            <div className="flex justify-between items-center mb-6 border-b pb-4">
                <h3 className="font-bold text-gray-800 text-lg">Sản phẩm khuyến mãi</h3>
                <button type="button" onClick={() => setShowSelector(true)} 
                    className="flex items-center gap-2 bg-blue-50 text-blue-600 px-4 py-2 rounded-lg font-semibold hover:bg-blue-100 transition active:scale-95">
                    <Plus size={18} /> Thêm sản phẩm
                </button>
            </div>
            
            {/* Table sản phẩm tương tự như cũ, giữ nguyên */}
            {selectedProducts.length > 0 && (
                <div className="overflow-x-auto">
                    <table className="w-full text-sm text-left">
                        <thead className="bg-gray-50 text-gray-700 uppercase text-xs font-bold">
                            <tr>
                                <th className="px-5 py-4">Sản phẩm</th>
                                <th className="px-5 py-4">Giá gốc</th>
                                <th className="px-5 py-4 w-48">Giá {isFlashSale ? 'Flash Sale' : 'KM'}</th>
                                <th className="px-5 py-4 w-40">Giới hạn SL</th>
                                <th className="px-5 py-4 w-16 text-center">Xóa</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-gray-100 bg-white">
                            {selectedProducts.map((item, idx) => {
                                const imgUrl = getImageUrl(item.product?.images);
                                return (
                                    <tr key={item.product_id} className="hover:bg-blue-50/30 transition-colors group">
                                        <td className="px-5 py-4">
                                            <div className="flex items-center gap-4">
                                                <img src={imgUrl.startsWith('http') ? imgUrl : `${process.env.NEXT_PUBLIC_STORAGE_URL}/${imgUrl}`} className="w-10 h-10 rounded border object-cover" />
                                                <div className="font-semibold text-gray-800 line-clamp-1">{item.product?.name}</div>
                                            </div>
                                        </td>
                                        <td className="px-5 py-4 text-gray-500">{Number(item.product?.price).toLocaleString()} ₫</td>
                                        <td className="px-5 py-4">
                                            <input type="number" className="w-full border rounded px-2 py-1.5 font-bold text-red-600 text-right"
                                                value={item.promotion_price} onChange={(e) => updateProductItem(idx, 'promotion_price', e.target.value)} />
                                        </td>
                                        <td className="px-5 py-4">
                                            <input type="number" placeholder="∞" className="w-full border rounded px-2 py-1.5 text-center"
                                                value={item.stock_limit} onChange={(e) => updateProductItem(idx, 'stock_limit', e.target.value)} />
                                        </td>
                                        <td className="px-5 py-4 text-center">
                                            <button type="button" onClick={() => removeProduct(idx)} className="text-gray-400 hover:text-red-600"><Trash2 size={18} /></button>
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>
            )}
        </div>

        <div className="fixed bottom-0 left-64 right-0 p-4 bg-white border-t border-gray-200 shadow-lg flex justify-end gap-3 z-40">
            <button type="button" onClick={() => router.back()} className="px-6 py-2.5 border rounded-lg hover:bg-gray-50">Hủy</button>
            <button type="submit" disabled={loading} className={`px-8 py-2.5 text-white rounded-lg font-bold flex items-center gap-2 shadow-md ${isFlashSale ? 'bg-orange-600 hover:bg-orange-700' : 'bg-blue-600 hover:bg-blue-700'}`}>
                {loading ? <span className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></span> : <Save size={20} />}
                {loading ? 'Đang lưu...' : 'Lưu chương trình'}
            </button>
        </div>
      </form>

      {showSelector && <ProductSelector selectedIds={selectedProducts.map(p => p.product_id)} onChange={handleSelectProducts} onClose={() => setShowSelector(false)} />}
    </>
  );
}
