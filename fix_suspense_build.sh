#!/bin/bash

echo "🛠️ Đang sửa lỗi Suspense Boundary và Build..."

# Ghi đè file apps/admin/app/products/page.tsx
cat << 'EOF' > /var/www/lica-project/apps/admin/app/products/page.tsx
"use client";
import { useState, useEffect, useCallback, Suspense } from "react";
import axios from "axios";
import Link from "next/link";
import { useSearchParams, useRouter, usePathname } from "next/navigation";
import { Plus, Search, Edit, Trash2, Loader2, ImageOff, ChevronLeft, ChevronRight } from "lucide-react";
import { Product } from "@/types/product";

interface PaginatedResponse {
  data: Product[];
  current_page: number;
  last_page: number;
  total: number;
  per_page: number;
}

// 1. Tách logic chính ra thành Component con (Content)
function ProductListContent() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams(); // Hook này gây lỗi nếu không có Suspense

  const [data, setData] = useState<PaginatedResponse | null>(null);
  const [loading, setLoading] = useState(true);
  
  const currentPage = Number(searchParams.get("page")) || 1;
  const searchTerm = searchParams.get("q") || "";
  const [searchInput, setSearchInput] = useState(searchTerm);

  const fetchProducts = useCallback(async () => {
    try {
      setLoading(true);
      const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product`, {
        params: { page: currentPage, q: searchTerm },
      });
      setData(res.data.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [currentPage, searchTerm]);

  useEffect(() => { fetchProducts(); }, [fetchProducts]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    const params = new URLSearchParams(searchParams.toString());
    if (searchInput) params.set("q", searchInput);
    else params.delete("q");
    params.set("page", "1");
    router.replace(`${pathname}?${params.toString()}`);
  };

  const handlePageChange = (newPage: number) => {
    if (newPage < 1 || (data && newPage > data.last_page)) return;
    const params = new URLSearchParams(searchParams.toString());
    params.set("page", newPage.toString());
    router.push(`${pathname}?${params.toString()}`);
  };

  const handleDelete = async (id: number) => {
    if (!confirm("Xóa sản phẩm này?")) return;
    try {
      await axios.delete(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/${id}`);
      fetchProducts();
    } catch (err) { alert("Lỗi xóa sản phẩm"); }
  };

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex flex-col md:flex-row justify-between items-center mb-6 gap-4">
        <h1 className="text-2xl font-bold text-gray-800">Sản phẩm</h1>
        <Link href="/products/create" className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700 shadow font-medium">
          <Plus size={18} /> Thêm mới
        </Link>
      </div>

      <div className="bg-white p-4 rounded-lg shadow-sm border border-gray-100 mb-6">
        <form onSubmit={handleSearch} className="flex gap-3">
          <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
            <input 
              type="text" placeholder="Tìm theo tên, SKU..." 
              className="w-full pl-10 pr-4 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 outline-none"
              value={searchInput} onChange={(e) => setSearchInput(e.target.value)}
            />
          </div>
          <button type="submit" className="px-4 py-2 bg-gray-800 text-white rounded-md hover:bg-gray-900">Tìm kiếm</button>
        </form>
      </div>

      <div className="bg-white rounded-lg shadow border overflow-hidden">
        <table className="w-full text-sm text-left">
          <thead className="bg-gray-50 text-gray-700 uppercase font-medium">
            <tr>
              <th className="px-4 py-3 w-16">Hình</th>
              <th className="px-4 py-3">Tên / SKU</th>
              <th className="px-4 py-3">Giá bán</th>
              <th className="px-4 py-3 text-center">Kho</th>
              <th className="px-4 py-3">Danh mục</th>
              <th className="px-4 py-3 text-right">Hành động</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
              <tr><td colSpan={6} className="p-8 text-center"><Loader2 className="animate-spin inline text-blue-600"/> Đang tải...</td></tr>
            ) : data?.data && data.data.length > 0 ? (
              data.data.map((p) => (
                <tr key={p.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3">
                    {p.thumbnail ? <img src={p.thumbnail} className="w-10 h-10 object-cover rounded border" /> : <div className="w-10 h-10 bg-gray-100 rounded flex items-center justify-center"><ImageOff size={16}/></div>}
                  </td>
                  <td className="px-4 py-3">
                    <div className="font-medium text-gray-900">{p.name}</div>
                    <div className="text-xs text-gray-500 font-mono">{p.sku || "_"}</div>
                  </td>
                  <td className="px-4 py-3 font-medium text-green-600">
                    {new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(Number(p.price))}
                    {p.sale_price && Number(p.sale_price) < Number(p.price) && (
                       <div className="text-xs text-red-500 line-through mt-0.5">
                         {new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(Number(p.price))}
                       </div>
                    )}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <span className={`px-2 py-1 rounded text-xs ${Number(p.stock_quantity) > 0 ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>{p.stock_quantity}</span>
                  </td>
                  <td className="px-4 py-3 text-gray-600">{p.category?.name || "-"}</td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex justify-end gap-2">
                      <Link href={`/products/${p.id}`} className="text-blue-600 hover:bg-blue-50 p-1 rounded"><Edit size={16}/></Link>
                      <button onClick={() => handleDelete(p.id)} className="text-red-600 hover:bg-red-50 p-1 rounded"><Trash2 size={16}/></button>
                    </div>
                  </td>
                </tr>
              ))
            ) : (
              <tr><td colSpan={6} className="p-8 text-center text-gray-500">Không tìm thấy sản phẩm.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {data && data.last_page > 1 && (
        <div className="mt-4 flex justify-end gap-2">
          <button disabled={data.current_page === 1} onClick={() => handlePageChange(data.current_page - 1)} className="p-2 border rounded hover:bg-gray-50 disabled:opacity-50"><ChevronLeft size={16} /></button>
          <span className="px-4 py-2 text-sm text-gray-600">Trang {data.current_page} / {data.last_page}</span>
          <button disabled={data.current_page === data.last_page} onClick={() => handlePageChange(data.current_page + 1)} className="p-2 border rounded hover:bg-gray-50 disabled:opacity-50"><ChevronRight size={16} /></button>
        </div>
      )}
    </div>
  );
}

// 2. Component chính bọc Suspense để tránh lỗi Build
export default function ProductList() {
  return (
    <Suspense fallback={<div className="flex justify-center p-10"><Loader2 className="animate-spin text-blue-600 w-8 h-8"/></div>}>
      <ProductListContent />
    </Suspense>
  );
}
EOF

echo "🔄 Đang build lại Admin App..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Đã sửa lỗi Suspense và Build xong!"
