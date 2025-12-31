"use client";
import { useEffect, useState } from "react";
import axios from "axios";
import Link from "next/link";
import { Product } from "@/types/product";
import { Plus, Search, Edit, Trash2, Filter } from "lucide-react";

export default function ProductList() {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState("all");

  const fetchProducts = async () => {
    try {
      const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product`);
      setProducts(res.data.data);
    } catch (error) {
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { fetchProducts(); }, []);

  const tabs = [
    { id: "all", label: "Tất Cả" },
    { id: "active", label: "Đang Hoạt Động" },
    { id: "soldout", label: "Hết Hàng" },
    { id: "violation", label: "Vi Phạm" },
  ];

  return (
    <div className="space-y-4">
      {/* Header Actions */}
      <div className="flex justify-between items-center">
        <h1 className="text-xl font-bold text-gray-800">Sản Phẩm</h1>
        <Link href="/products/create" className="bg-yellow-500 hover:bg-yellow-600 text-white px-4 py-2 rounded shadow-sm text-sm font-medium flex items-center gap-2">
          <Plus size={16} /> Thêm 1 sản phẩm mới
        </Link>
      </div>

      {/* Main Card */}
      <div className="bg-white shadow-sm rounded-md border border-gray-200">
        
        {/* Status Tabs */}
        <div className="flex border-b px-4">
          {tabs.map(tab => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`px-6 py-4 text-sm font-medium transition-colors border-b-2 ${
                activeTab === tab.id 
                ? "border-yellow-500 text-yellow-600" 
                : "border-transparent text-gray-500 hover:text-gray-700"
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>

        {/* Filter Bar */}
        <div className="p-4 grid grid-cols-12 gap-4 bg-gray-50/50 border-b">
          <div className="col-span-5 relative">
            <input 
              type="text" 
              placeholder="Tìm tên sản phẩm, SKU..." 
              className="w-full border border-gray-300 rounded pl-9 pr-3 py-2 text-sm focus:border-yellow-500 focus:outline-none"
            />
            <Search className="absolute left-3 top-2.5 text-gray-400" size={16} />
          </div>
          <div className="col-span-3">
            <select className="w-full border border-gray-300 rounded px-3 py-2 text-sm focus:border-yellow-500 outline-none bg-white">
              <option>Danh mục: Tất cả</option>
            </select>
          </div>
          <div className="col-span-2">
             <button className="w-full border border-yellow-500 text-yellow-600 rounded px-3 py-2 text-sm font-medium hover:bg-yellow-50">
               Tìm kiếm
             </button>
          </div>
        </div>

        {/* Table */}
        <div className="overflow-x-auto">
          <table className="w-full text-left">
            <thead className="bg-gray-100 text-gray-600 text-xs uppercase font-semibold">
              <tr>
                <th className="p-4 w-12"><input type="checkbox" /></th>
                <th className="p-4">Tên sản phẩm</th>
                <th className="p-4">Phân loại hàng</th>
                <th className="p-4 text-right">Giá</th>
                <th className="p-4 text-center">Kho hàng</th>
                <th className="p-4 text-center">Thao tác</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 text-sm">
              {loading ? (
                <tr><td colSpan={6} className="p-8 text-center text-gray-500">Đang tải dữ liệu...</td></tr>
              ) : products.length === 0 ? (
                <tr><td colSpan={6} className="p-8 text-center text-gray-500">Không tìm thấy sản phẩm nào.</td></tr>
              ) : (
                products.map((p) => (
                  <tr key={p.id} className="hover:bg-gray-50 transition">
                    <td className="p-4"><input type="checkbox" /></td>
                    <td className="p-4">
                      <div className="flex gap-3">
                        <div className="w-12 h-12 flex-shrink-0 border rounded bg-gray-100 overflow-hidden">
                          {p.thumbnail ? (
                            <img src={p.thumbnail} alt="" className="w-full h-full object-cover" />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center text-[10px] text-gray-400">NO IMG</div>
                          )}
                        </div>
                        <div>
                          <Link href={`/products/${p.id}`} className="font-medium text-blue-600 hover:underline line-clamp-2 mb-1">
                            {p.name}
                          </Link>
                          <div className="text-xs text-gray-400">SKU: {p.sku || "-"}</div>
                        </div>
                      </div>
                    </td>
                    {/* FIX ERROR HERE: Access .name property */}
                    <td className="p-4 text-gray-500 text-xs">
                        {p.category?.name || "Chưa phân loại"}
                    </td>
                    <td className="p-4 text-right">
                       <div className="text-gray-800">{Number(p.sale_price || p.price).toLocaleString('vi-VN')} ₫</div>
                    </td>
                    <td className="p-4 text-center">
                        <span className="text-gray-700">{p.stock_quantity}</span>
                    </td>
                    <td className="p-4 text-center">
                      <div className="flex flex-col gap-2 items-center">
                        <Link href={`/products/${p.id}`} className="text-blue-600 hover:text-blue-800 text-xs font-medium">Sửa</Link>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
