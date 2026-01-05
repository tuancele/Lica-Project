"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { Search, CheckSquare, Square, X, Loader2 } from "lucide-react";

// Định nghĩa đúng kiểu dữ liệu trả về từ Backend
interface Product { 
    id: number; 
    name: string; 
    images: string[] | string; 
    sku: string; 
    price: number; 
}

interface Props {
  selectedIds: number[];
  onChange: (products: Product[]) => void; // Trả về cả object product để form sử dụng
  onClose: () => void;
}

export default function ProductSelector({ selectedIds, onChange, onClose }: Props) {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState("");
  // Lưu danh sách ID đang chọn trong phiên làm việc của modal
  const [localSelectedIds, setLocalSelectedIds] = useState<number[]>(selectedIds);
  // Lưu map các sản phẩm đã chọn để trả về form
  const [selectedProductMap, setSelectedProductMap] = useState<Record<number, Product>>({});

  useEffect(() => {
    fetchProducts();
  }, [search]);

  const fetchProducts = async () => {
    setLoading(true);
    try {
        // Fix: Dùng baseURL từ env, không hardcode /api/v1 thêm lần nữa nếu env đã có
        const baseURL = process.env.NEXT_PUBLIC_API_URL?.endsWith('/api/v1') 
            ? process.env.NEXT_PUBLIC_API_URL 
            : `${process.env.NEXT_PUBLIC_API_URL}/api/v1`;

        const res = await axios.get(`${baseURL}/product`, {
            params: { q: search, limit: 20 }
        });
        
        // Backend trả về: { status: 200, data: { data: [...] } } hoặc { data: [...] }
        const items = res.data.data?.data || res.data.data || [];
        setProducts(items);
    } catch (e) { 
        console.error("Lỗi tải sản phẩm:", e); 
    } finally { 
        setLoading(false); 
    }
  };

  const toggleSelect = (product: Product) => {
    setLocalSelectedIds(prev => {
        const isSelected = prev.includes(product.id);
        if (isSelected) {
            // Bỏ chọn: Xóa khỏi map tạm
            const newMap = { ...selectedProductMap };
            delete newMap[product.id];
            setSelectedProductMap(newMap);
            return prev.filter(id => id !== product.id);
        } else {
            // Chọn: Thêm vào map tạm
            setSelectedProductMap(prevMap => ({ ...prevMap, [product.id]: product }));
            return [...prev, product.id];
        }
    });
  };

  const handleConfirm = () => {
    // Lấy danh sách product objects dựa trên các ID đã chọn
    // Cần merge với các sản phẩm đã có sẵn (nếu search không tìm ra chúng lúc này)
    // Tuy nhiên, logic đơn giản là trả về danh sách các sản phẩm user vừa tương tác + list cũ
    // Cách tốt nhất: Callback onChange nhận danh sách ID, hoặc danh sách Product.
    // Ở đây ta trả về danh sách Product objects của những item ĐANG được chọn trong modal
    // Lưu ý: Những item đã chọn từ trước (selectedIds) nhưng không hiển thị trong search hiện tại 
    // cần được xử lý ở Form cha, hoặc component này cần fetch full details.
    // Để đơn giản: Component này trả về danh sách các sản phẩm MỚI được chọn trong phiên này.
    
    const selectedProductsList = Object.values(selectedProductMap);
    // Lọc chỉ những thằng nằm trong localSelectedIds
    const finalSelection = selectedProductsList.filter(p => localSelectedIds.includes(p.id));
    
    onChange(finalSelection);
    onClose();
  };

  // Helper hiển thị ảnh
  const getImageUrl = (imgData: any) => {
    if (!imgData) return "https://placehold.co/50x50?text=NoImg";
    if (typeof imgData === 'string') {
        try {
            const parsed = JSON.parse(imgData);
            return Array.isArray(parsed) ? parsed[0] : imgData;
        } catch { return imgData; }
    }
    if (Array.isArray(imgData)) return imgData[0];
    return "https://placehold.co/50x50?text=NoImg";
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-[9999] p-4 backdrop-blur-sm">
      <div className="bg-white rounded-xl w-full max-w-2xl h-[85vh] flex flex-col shadow-2xl animate-in fade-in zoom-in duration-200">
        {/* Header */}
        <div className="p-4 border-b flex justify-between items-center bg-gray-50 rounded-t-xl">
            <h3 className="font-bold text-lg text-gray-800">Chọn sản phẩm áp dụng</h3>
            <button onClick={onClose} className="p-1 hover:bg-gray-200 rounded-full transition"><X className="text-gray-500 hover:text-red-500" size={20}/></button>
        </div>

        {/* Search */}
        <div className="p-4 border-b bg-white">
            <div className="relative">
                <Search className="absolute left-3 top-2.5 text-gray-400" size={18}/>
                <input 
                    type="text" 
                    placeholder="Tìm tên sản phẩm, mã SKU..." 
                    className="w-full pl-10 border border-gray-300 rounded-lg p-2 outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition"
                    value={search} 
                    onChange={e => setSearch(e.target.value)}
                    autoFocus 
                />
            </div>
        </div>

        {/* List */}
        <div className="flex-1 overflow-y-auto p-2 bg-gray-50/50">
            {loading ? (
                <div className="flex flex-col items-center justify-center h-full text-gray-500 gap-2">
                    <Loader2 className="animate-spin text-blue-600" size={32}/>
                    <span className="text-sm">Đang tải dữ liệu...</span>
                </div>
            ) : products.length === 0 ? (
                <div className="flex flex-col items-center justify-center h-full text-gray-400">
                    <Search size={48} className="mb-2 opacity-20"/>
                    <p>Không tìm thấy sản phẩm nào</p>
                </div>
            ) : (
                <div className="space-y-2">
                    {products.map(p => {
                        const isSelected = localSelectedIds.includes(p.id);
                        const imgUrl = getImageUrl(p.images);
                        
                        return (
                            <div key={p.id} onClick={() => toggleSelect(p)} 
                                className={`flex items-center gap-4 p-3 rounded-lg cursor-pointer transition-all border ${isSelected ? 'bg-blue-50 border-blue-500 shadow-sm' : 'bg-white hover:bg-gray-100 border-gray-200 hover:border-blue-300'}`}>
                                <div className={`w-5 h-5 rounded border flex items-center justify-center transition-colors ${isSelected ? 'bg-blue-600 border-blue-600' : 'bg-white border-gray-400'}`}>
                                    {isSelected && <CheckSquare className="text-white w-3.5 h-3.5" strokeWidth={3}/>}
                                </div>
                                
                                <div className="w-12 h-12 rounded-md border border-gray-200 overflow-hidden bg-white shrink-0">
                                    <img src={imgUrl.startsWith('http') ? imgUrl : `${process.env.NEXT_PUBLIC_STORAGE_URL}/${imgUrl}`} className="w-full h-full object-cover" alt="" />
                                </div>
                                
                                <div className="flex-1 min-w-0">
                                    <div className="font-semibold text-gray-800 line-clamp-1 text-sm">{p.name}</div>
                                    <div className="text-xs text-gray-500 mt-0.5 flex items-center gap-2">
                                        <span className="bg-gray-100 px-1.5 py-0.5 rounded text-gray-600 font-mono">{p.sku}</span>
                                        <span>•</span>
                                        <span className="text-blue-600 font-medium">{new Intl.NumberFormat('vi-VN').format(p.price)} ₫</span>
                                    </div>
                                </div>
                            </div>
                        )
                    })}
                </div>
            )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t flex justify-between items-center bg-white rounded-b-xl shadow-[0_-4px_6px_-1px_rgba(0,0,0,0.05)] z-10">
            <span className="text-sm text-gray-600">
                Đang chọn: <b className="text-blue-600 text-lg">{localSelectedIds.length}</b> sản phẩm
            </span>
            <div className="flex gap-3">
                <button onClick={onClose} className="px-5 py-2.5 border border-gray-300 rounded-lg hover:bg-gray-50 font-medium text-sm transition">Hủy bỏ</button>
                <button onClick={handleConfirm} className="px-6 py-2.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700 font-bold text-sm shadow-md hover:shadow-lg transition active:scale-95">
                    Xác nhận thêm
                </button>
            </div>
        </div>
      </div>
    </div>
  );
}
