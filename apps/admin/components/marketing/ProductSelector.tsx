"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { Search, CheckSquare, Square, X, Loader2 } from "lucide-react";

interface Product { id: number; name: string; thumbnail: string; sku: string; price: number; }

interface Props {
  selectedIds: number[];
  onChange: (ids: number[]) => void;
  onClose: () => void;
}

export default function ProductSelector({ selectedIds, onChange, onClose }: Props) {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(false);
  const [search, setSearch] = useState("");
  const [localSelected, setLocalSelected] = useState<number[]>(selectedIds);

  useEffect(() => {
    fetchProducts();
  }, [search]);

  const fetchProducts = async () => {
    setLoading(true);
    try {
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product`, {
            params: { q: search, limit: 20 } // Limit nhỏ để load nhanh
        });
        setProducts(res.data.data.data);
    } catch (e) { console.error(e); } finally { setLoading(false); }
  };

  const toggleSelect = (id: number) => {
    setLocalSelected(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id]);
  };

  const handleConfirm = () => {
    onChange(localSelected);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-xl w-full max-w-2xl h-[80vh] flex flex-col shadow-2xl">
        {/* Header */}
        <div className="p-4 border-b flex justify-between items-center bg-gray-50 rounded-t-xl">
            <h3 className="font-bold text-lg">Chọn sản phẩm áp dụng</h3>
            <button onClick={onClose}><X className="text-gray-500 hover:text-red-500"/></button>
        </div>

        {/* Search */}
        <div className="p-4 border-b">
            <div className="relative">
                <Search className="absolute left-3 top-2.5 text-gray-400" size={18}/>
                <input type="text" placeholder="Tìm tên sản phẩm, SKU..." className="w-full pl-10 border rounded p-2 outline-none focus:ring-2 focus:ring-blue-500"
                    value={search} onChange={e => setSearch(e.target.value)} />
            </div>
        </div>

        {/* List */}
        <div className="flex-1 overflow-y-auto p-2">
            {loading ? <div className="text-center p-10"><Loader2 className="animate-spin inline"/></div> : (
                <div className="space-y-1">
                    {products.map(p => {
                        const isSelected = localSelected.includes(p.id);
                        return (
                            <div key={p.id} onClick={() => toggleSelect(p.id)} 
                                className={`flex items-center gap-3 p-3 rounded-lg cursor-pointer transition border ${isSelected ? 'bg-blue-50 border-blue-200' : 'hover:bg-gray-50 border-transparent'}`}>
                                {isSelected ? <CheckSquare className="text-blue-600 shrink-0"/> : <Square className="text-gray-400 shrink-0"/>}
                                <img src={p.thumbnail} className="w-10 h-10 object-cover rounded border bg-white" />
                                <div>
                                    <div className="font-medium line-clamp-1">{p.name}</div>
                                    <div className="text-xs text-gray-500">SKU: {p.sku} | {new Intl.NumberFormat('vi-VN').format(p.price)}đ</div>
                                </div>
                            </div>
                        )
                    })}
                </div>
            )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t flex justify-between items-center bg-gray-50 rounded-b-xl">
            <span className="text-sm font-medium">Đã chọn: <b className="text-blue-600">{localSelected.length}</b> sản phẩm</span>
            <div className="flex gap-2">
                <button onClick={onClose} className="px-4 py-2 border rounded hover:bg-gray-100">Hủy</button>
                <button onClick={handleConfirm} className="px-6 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 font-bold">Xác nhận</button>
            </div>
        </div>
      </div>
    </div>
  );
}
