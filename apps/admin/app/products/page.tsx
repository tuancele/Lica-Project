"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import Link from "next/link";
import { Plus, Search, Edit, Trash2, Loader2, ImageOff } from "lucide-react";

export default function ProductList() {
  const [products, setProducts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  const fetchProducts = async () => {
    try {
      setLoading(true);
      const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product`);
      setProducts(res.data.data?.data || []); // Laravel paginate trả về object {data: []}
    } catch (err) { 
      console.error(err); 
      setProducts([]); // Fallback nếu lỗi
    } finally { setLoading(false); }
  };

  useEffect(() => { fetchProducts(); }, []);

  const handleDelete = async (id: number) => {
    if (!confirm("Xóa sản phẩm này?")) return;
    try {
      await axios.delete(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/${id}`);
      fetchProducts();
    } catch (err) { alert("Lỗi xóa sản phẩm"); }
  };

  // Filter local đơn giản
  const filteredProducts = products.filter(p => 
    p.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    p.sku?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Danh sách sản phẩm</h1>
        <Link href="/products/create" className="bg-blue-600 text-white px-4 py-2 rounded-md flex items-center gap-2 hover:bg-blue-700 shadow">
          <Plus size={18} /> Thêm sản phẩm
        </Link>
      </div>

      {/* Toolbar */}
      <div className="mb-4 flex gap-4">
        <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
            <input 
                type="text" 
                placeholder="Tìm kiếm theo tên, SKU..." 
                className="w-full pl-10 pr-4 py-2 border rounded-md focus:ring-2 ring-blue-500 outline-none"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
            />
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-lg shadow border overflow-hidden">
        <table className="w-full text-sm text-left">
            <thead className="bg-gray-50 text-gray-700 uppercase font-medium">
                <tr>
                    <th className="px-4 py-3 w-16">Hình</th>
                    <th className="px-4 py-3">Tên sản phẩm / SKU</th>
                    <th className="px-4 py-3">Giá bán</th>
                    <th className="px-4 py-3">Kho</th>
                    <th className="px-4 py-3">Thương hiệu</th>
                    <th className="px-4 py-3 text-right">Hành động</th>
                </tr>
            </thead>
            <tbody>
                {loading ? (
                    <tr><td colSpan={6} className="p-8 text-center"><Loader2 className="animate-spin inline text-blue-600"/> Đang tải...</td></tr>
                ) : filteredProducts.length > 0 ? (
                    filteredProducts.map((p) => (
                        <tr key={p.id} className="border-b hover:bg-gray-50">
                            <td className="px-4 py-3">
                                {p.thumbnail ? (
                                    <img src={p.thumbnail} alt="" className="w-10 h-10 object-cover rounded border" />
                                ) : (
                                    <div className="w-10 h-10 bg-gray-100 rounded flex items-center justify-center text-gray-400"><ImageOff size={16}/></div>
                                )}
                            </td>
                            <td className="px-4 py-3">
                                <div className="font-medium text-gray-900">{p.name}</div>
                                <div className="text-xs text-gray-500 font-mono">{p.sku || "_"}</div>
                            </td>
                            <td className="px-4 py-3 font-medium text-green-600">
                                {new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(p.price)}
                            </td>
                            <td className="px-4 py-3">
                                <span className={`px-2 py-1 rounded text-xs ${p.stock_quantity > 0 ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
                                    {p.stock_quantity}
                                </span>
                            </td>
                            <td className="px-4 py-3 text-gray-600">
                                {p.brand?.name || "-"}
                            </td>
                            <td className="px-4 py-3 text-right">
                                <div className="flex justify-end gap-2">
                                    <Link href={`/products/${p.id}`} className="text-blue-600 hover:bg-blue-50 p-1 rounded"><Edit size={16}/></Link>
                                    <button onClick={() => handleDelete(p.id)} className="text-red-600 hover:bg-red-50 p-1 rounded"><Trash2 size={16}/></button>
                                </div>
                            </td>
                        </tr>
                    ))
                ) : (
                    <tr><td colSpan={6} className="p-8 text-center text-gray-500">Không tìm thấy sản phẩm nào.</td></tr>
                )}
            </tbody>
        </table>
      </div>
    </div>
  );
}
