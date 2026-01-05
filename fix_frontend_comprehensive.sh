#!/bin/bash

FE_ROOT="/var/www/lica-project/apps/user"

echo "========================================================"
echo "   FIX LỖI TOÀN DIỆN FRONTEND (IMAGES & CATEGORY)"
echo "========================================================"

# 1. Nâng cấp hàm xử lý ảnh (lib/axios.ts) để chấp nhận mọi loại dữ liệu
echo ">>> [1/3] Cập nhật lib/axios.ts (Fix e.startsWith error)..."
cat << 'EOF' > $FE_ROOT/lib/axios.ts
import axios from 'axios';

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
});

export const getImageUrl = (path: string | string[] | any) => {
  // 1. Nếu không có path -> Trả về placeholder
  if (!path) return 'https://placehold.co/300x300?text=No+Image';

  let finalPath = path;

  // 2. Nếu là Array -> Lấy phần tử đầu tiên
  if (Array.isArray(path)) {
    if (path.length === 0) return 'https://placehold.co/300x300?text=No+Image';
    finalPath = path[0];
  } 
  // 3. Nếu là String nhưng dạng JSON mảng '["img.jpg"]' -> Parse lấy phần tử đầu
  else if (typeof path === 'string' && path.startsWith('[')) {
    try {
        const parsed = JSON.parse(path);
        if (Array.isArray(parsed) && parsed.length > 0) finalPath = parsed[0];
    } catch (e) {
        // Parse lỗi thì giữ nguyên string gốc
    }
  }

  // 4. Đảm bảo finalPath là string
  if (typeof finalPath !== 'string') return 'https://placehold.co/300x300?text=Error';

  // 5. Kiểm tra http
  if (finalPath.startsWith('http')) return finalPath;
  
  // 6. Ghép với Storage URL
  // Xóa dấu / ở đầu nếu có để tránh //
  const cleanPath = finalPath.startsWith('/') ? finalPath.substring(1) : finalPath;
  return `${process.env.NEXT_PUBLIC_STORAGE_URL}/${cleanPath}`;
};

export default api;
EOF

# 2. Tạo trang Category (Fix lỗi 404 Not Found)
echo ">>> [2/3] Tạo trang Category ([id]/page.tsx)..."
mkdir -p $FE_ROOT/app/category/[id]

cat << 'EOF' > $FE_ROOT/app/category/[id]/page.tsx
'use client';

import { useState, useEffect, use } from 'react';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import Navigation from '@/components/layout/Navigation';
import ProductCard from '@/components/common/ProductCard';
import { ProductService, Product } from '@/services/product.service';
import { Loader2 } from 'lucide-react';

export default function CategoryPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [categoryName, setCategoryName] = useState('Danh mục');

  useEffect(() => {
    const fetchData = async () => {
      setLoading(true);
      try {
        // Lấy danh sản phẩm theo category_id
        const res = await ProductService.getProducts({ category_id: id });
        setProducts(res || []);
        
        // Lấy tên danh mục (Optional: Có thể viết thêm API getCategoryDetail)
        const cats = await ProductService.getCategories();
        const currentCat = cats.find((c: any) => c.id == id);
        if (currentCat) setCategoryName(currentCat.name);
        
      } catch (error) {
        console.error(error);
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [id]);

  return (
    <div className="min-h-screen bg-gray-50 font-sans">
      <Header />
      <Navigation />
      
      <main className="container mx-auto px-4 py-8">
        <div className="flex items-center justify-between mb-6">
            <h1 className="text-2xl font-bold text-gray-800 uppercase border-l-4 border-lica-primary pl-3">
                {categoryName}
            </h1>
            <span className="text-sm text-gray-500">{products.length} sản phẩm</span>
        </div>

        {loading ? (
            <div className="flex justify-center py-20">
                <Loader2 className="animate-spin text-lica-primary w-10 h-10" />
            </div>
        ) : products.length > 0 ? (
            <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-3">
                {products.map((product) => (
                    <ProductCard key={product.id} product={product} />
                ))}
            </div>
        ) : (
            <div className="text-center py-16 bg-white rounded-lg shadow-sm">
                <p className="text-gray-500">Chưa có sản phẩm nào trong danh mục này.</p>
            </div>
        )}
      </main>
      
      <Footer />
    </div>
  );
}
EOF

# 3. Build lại Frontend
echo ">>> [3/3] Rebuilding Frontend..."
cd $FE_ROOT
rm -rf .next # Xóa cache cũ để chắc chắn code mới được áp dụng
npm run build

echo "========================================================"
echo "   ĐÃ SỬA XONG! VUI LÒNG RESTART PM2"
echo "   Command: pm2 restart all"
echo "========================================================"
