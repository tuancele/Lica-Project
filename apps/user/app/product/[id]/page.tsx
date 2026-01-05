'use client';

import { useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import { ProductService, Product } from '@/services/product.service';
import { getImageUrl } from '@/lib/axios';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';
import Navigation from '@/components/layout/Navigation';
import { Star, ShoppingCart, Truck, ShieldCheck } from 'lucide-react';
import { useCart } from '@/context/CartContext';

export default function ProductDetail() {
  const { id } = useParams();
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const { addToCart } = useCart();

  useEffect(() => {
    if (id) {
        ProductService.getProductDetail(id as string).then(data => {
            setProduct(data);
            setLoading(false);
        });
    }
  }, [id]);

  if (loading) return <div className="min-h-screen flex items-center justify-center">Đang tải...</div>;
  if (!product) return <div className="min-h-screen flex items-center justify-center">Không tìm thấy sản phẩm</div>;

  // Xử lý ảnh
  let mainImage = null;
  if (product.images) {
    if (Array.isArray(product.images) && product.images.length > 0) mainImage = product.images[0];
    else if (typeof product.images === 'string') {
        try { mainImage = JSON.parse(product.images)[0]; } catch { mainImage = product.images; }
    }
  }
  const imageUrl = getImageUrl(mainImage);
  const displayPrice = product.sale_price || product.price;
  const discount = product.sale_price ? Math.round(((product.price - product.sale_price) / product.price) * 100) : 0;

  return (
    <div className="bg-gray-50 min-h-screen font-sans">
      <Header />
      <Navigation />
      
      <div className="container-custom py-6">
        <div className="bg-white rounded-xl shadow-sm overflow-hidden">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-8 p-6">
                {/* Left: Images */}
                <div className="relative">
                    <div className="aspect-square bg-gray-100 rounded-lg overflow-hidden border border-gray-100">
                        <img src={imageUrl} alt={product.name} className="w-full h-full object-contain mix-blend-multiply" />
                    </div>
                </div>

                {/* Right: Info */}
                <div>
                    <h1 className="text-xl md:text-2xl font-bold text-gray-800 mb-2">{product.name}</h1>
                    <div className="flex items-center gap-4 mb-4 text-sm text-gray-500">
                        <div className="flex items-center text-yellow-400">
                            <span className="font-bold mr-1">5.0</span>
                            <Star className="w-4 h-4 fill-current" />
                            <Star className="w-4 h-4 fill-current" />
                            <Star className="w-4 h-4 fill-current" />
                            <Star className="w-4 h-4 fill-current" />
                            <Star className="w-4 h-4 fill-current" />
                        </div>
                        <span>|</span>
                        <span>Đã bán 1.2k</span>
                    </div>

                    <div className="bg-gray-50 p-4 rounded-lg mb-6">
                        <div className="flex items-end gap-3">
                            <span className="text-3xl font-bold text-lica-red">{displayPrice.toLocaleString('vi-VN')} ₫</span>
                            {discount > 0 && (
                                <>
                                    <span className="text-gray-400 line-through mb-1">{product.price.toLocaleString('vi-VN')} ₫</span>
                                    <span className="bg-red-100 text-lica-red text-xs font-bold px-2 py-1 rounded mb-1">-{discount}%</span>
                                </>
                            )}
                        </div>
                    </div>

                    {/* Policies */}
                    <div className="grid grid-cols-2 gap-4 mb-6">
                        <div className="flex items-center gap-2 text-sm text-gray-600">
                            <Truck className="w-5 h-5 text-lica-primary" />
                            <span>Giao hàng miễn phí 2H</span>
                        </div>
                        <div className="flex items-center gap-2 text-sm text-gray-600">
                            <ShieldCheck className="w-5 h-5 text-lica-primary" />
                            <span>Chính hãng 100%</span>
                        </div>
                    </div>

                    {/* Actions */}
                    <div className="flex gap-4 mt-8">
                        <button 
                            onClick={() => { addToCart(product, 1); alert('Đã thêm vào giỏ!'); }}
                            className="flex-1 bg-lica-primary/10 text-lica-primary border border-lica-primary font-bold py-3 rounded-lg flex items-center justify-center gap-2 hover:bg-lica-primary/20 transition-colors"
                        >
                            <ShoppingCart className="w-5 h-5" />
                            Thêm vào giỏ
                        </button>
                        <button className="flex-1 bg-lica-red text-white font-bold py-3 rounded-lg hover:bg-red-700 transition-colors shadow-lg shadow-red-200">
                            Mua ngay
                        </button>
                    </div>
                </div>
            </div>
            
            {/* Description */}
            <div className="border-t border-gray-100 p-6">
                <h3 className="text-lg font-bold uppercase mb-4 text-gray-800">Thông tin sản phẩm</h3>
                <div className="prose max-w-none text-sm text-gray-600">
                    {product.description || "Đang cập nhật thông tin sản phẩm..."}
                </div>
            </div>
        </div>
      </div>
      <Footer />
    </div>
  );
}
