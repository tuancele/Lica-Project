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
