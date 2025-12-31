#!/bin/bash

echo "🚀 Bắt đầu cập nhật tính năng Product (Full Feature)..."

# ==============================================================================
# 1. CẬP NHẬT BACKEND: ProductController.php
# ==============================================================================
echo "📝 Đang cập nhật Backend Controller..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/Product/app/Http/Controllers/ProductController.php
<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Product;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Validator;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $query = Product::with(['category', 'brand', 'origin', 'unit']);

        if ($request->has('q') && !empty($request->q)) {
            $q = $request->q;
            $query->where(function($sub) use ($q) {
                $sub->where('name', 'like', "%{$q}%")
                    ->orWhere('sku', 'like', "%{$q}%");
            });
        }

        $query->orderBy('created_at', 'desc');

        return response()->json([
            'status' => 200, 
            'data' => $query->paginate($request->get('limit', 20))
        ]);
    }

    public function show($id)
    {
        if (!is_numeric($id)) return response()->json(['message' => 'ID không hợp lệ'], 404);
        $product = Product::with(['category', 'brand', 'origin', 'unit'])->find($id);
        return $product 
            ? response()->json(['status' => 200, 'data' => $product]) 
            : response()->json(['message' => 'Không tìm thấy'], 404);
    }

    public function store(Request $request) { return $this->saveProduct($request); }

    public function update(Request $request, $id) { return $this->saveProduct($request, $id); }

    private function saveProduct(Request $request, $id = null)
    {
        try {
            $rules = [
                'name' => 'required|string|max:255',
                'category_id' => 'required|numeric',
                'price' => 'required|numeric|min:0',
                'sku' => 'nullable|string|max:50|unique:products,sku' . ($id ? ",$id" : ''),
                'stock_quantity' => 'nullable|integer|min:0',
            ];

            $validator = Validator::make($request->all(), $rules);

            if ($validator->fails()) {
                return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);
            }

            $input = $request->all();
            
            $columns = Schema::getColumnListing('products');
            $data = array_intersect_key($input, array_flip($columns));

            $numericFields = ['price', 'sale_price', 'stock_quantity', 'weight', 'length', 'width', 'height', 'category_id', 'brand_id', 'origin_id', 'unit_id'];
            foreach ($numericFields as $field) {
                if (array_key_exists($field, $data)) {
                    $val = $data[$field];
                    $data[$field] = (is_numeric($val) && $val > 0) ? (float)$val : null;
                }
            }

            if (empty($data['slug'])) {
                $data['slug'] = Str::slug($data['name']) . '-' . uniqid();
            }
            if (empty($data['sku'])) {
                $data['sku'] = 'SKU-' . strtoupper(Str::random(8));
            }

            if (isset($input['images']) && is_array($input['images'])) {
                $data['images'] = array_values(array_filter($input['images']));
                $data['thumbnail'] = $data['images'][0] ?? null;
            }
            if (isset($input['skin_type_ids'])) {
                $data['skin_type_ids'] = is_array($input['skin_type_ids']) ? array_map('intval', $input['skin_type_ids']) : [];
            }

            if ($id) {
                $product = Product::findOrFail($id);
                $product->update($data);
            } else {
                $product = Product::create($data);
            }

            return response()->json(['status' => 200, 'data' => $product, 'message' => 'Lưu thành công']);

        } catch (\Exception $e) {
            Log::error('Product Save Error: ' . $e->getMessage());
            return response()->json(['message' => 'Lỗi server: ' . $e->getMessage()], 500);
        }
    }

    public function destroy($id)
    {
        Product::destroy($id);
        return response()->json(['status' => 200, 'message' => 'Đã xóa sản phẩm']);
    }
}
EOF

# ==============================================================================
# 2. CẬP NHẬT FRONTEND: Danh sách sản phẩm (Search & Pagination)
# ==============================================================================
echo "📝 Đang cập nhật Frontend List Page..."
cat << 'EOF' > /var/www/lica-project/apps/admin/app/products/page.tsx
"use client";
import { useState, useEffect, useCallback } from "react";
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

export default function ProductList() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

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
    const params = new URLSearchParams(searchParams);
    if (searchInput) params.set("q", searchInput);
    else params.delete("q");
    params.set("page", "1");
    router.replace(`${pathname}?${params.toString()}`);
  };

  const handlePageChange = (newPage: number) => {
    if (newPage < 1 || (data && newPage > data.last_page)) return;
    const params = new URLSearchParams(searchParams);
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
                    {new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(p.price)}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <span className={`px-2 py-1 rounded text-xs ${p.stock_quantity > 0 ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>{p.stock_quantity}</span>
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
EOF

# ==============================================================================
# 3. CẬP NHẬT FRONTEND: Trang sửa sản phẩm (Edit Page)
# ==============================================================================
echo "📝 Đang cập nhật Frontend Edit Page..."
cat << 'EOF' > /var/www/lica-project/apps/admin/app/products/[id]/page.tsx
"use client";

import { useEffect, useState, use } from "react";
import ProductForm from "@/components/ProductForm";
import axios from "axios";
import { Loader2, ArrowLeft } from "lucide-react";
import Link from "next/link";
import { Product } from "@/types/product";

export default function EditProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const fetchProduct = async () => {
      try {
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/${id}`);
        setProduct(res.data.data);
      } catch (err) {
        console.error(err);
        setError("Không tìm thấy sản phẩm.");
      } finally {
        setLoading(false);
      }
    };
    if (id) fetchProduct();
  }, [id]);

  if (loading) return <div className="flex h-screen items-center justify-center"><Loader2 className="animate-spin text-blue-600" /></div>;

  if (error || !product) {
    return (
      <div className="p-8 text-center">
        <h2 className="text-red-600 font-bold mb-2">Lỗi</h2>
        <p className="mb-4">{error}</p>
        <Link href="/products" className="text-blue-600 hover:underline flex items-center justify-center gap-2"><ArrowLeft size={16} /> Quay lại</Link>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="flex items-center gap-3 mb-6">
        <Link href="/products" className="p-2 rounded-full hover:bg-gray-100 text-gray-500"><ArrowLeft size={20}/></Link>
        <h1 className="text-2xl font-bold text-gray-800">Sửa sản phẩm: {product.name}</h1>
      </div>
      <ProductForm initialData={product} isEdit={true} />
    </div>
  );
}
EOF

# ==============================================================================
# 4. BUILD & RESTART
# ==============================================================================
echo "🔄 Đang build và khởi động lại ứng dụng Admin..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Đã cập nhật xong hoàn toàn! Hãy kiểm tra tại http://admin.lica.vn"
