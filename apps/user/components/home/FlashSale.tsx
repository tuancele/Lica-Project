'use client';

import { useEffect, useState } from 'react';
import ProductCard from "../common/ProductCard";
import { Zap, Clock } from 'lucide-react';
import { ProductService, Product } from '@/services/product.service';

export default function FlashSale() {
  const [products, setProducts] = useState<Product[]>([]);
  const [endTime, setEndTime] = useState<Date | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchFlashSale = async () => {
      try {
        // 1. Lấy Flash Sale đang active
        const program = await ProductService.getActiveFlashSale();
        
        if (program && program.items && program.items.length > 0) {
            // Map items về dạng Product chuẩn
            const mappedProducts = program.items.map((item: any) => ({
                ...item.product,
                // Override giá bằng giá khuyến mãi từ bảng items
                sale_price: Number(item.promotion_price),
                // Gán discount info để ProductCard nhận diện
                discount_info: {
                    type: 'flash_sale',
                    price: Number(item.promotion_price),
                    end_at: program.end_at
                },
                has_discount: true
            }));
            
            setProducts(mappedProducts);
            setEndTime(new Date(program.end_at));
        } else {
            // Fallback: Nếu không có Flash Sale nào, ẩn component hoặc lấy SP ngẫu nhiên
            // Ở đây ta ẩn đi cho đúng logic
            setProducts([]);
        }
      } catch (err) {
        console.error("Error fetching Flash Sale:", err);
      } finally {
        setLoading(false);
      }
    };
    fetchFlashSale();
  }, []);

  if (!loading && products.length === 0) return null;

  return (
    <section className="bg-gradient-to-r from-orange-500 via-red-500 to-pink-500 rounded-xl my-6 p-[2px] shadow-md">
      <div className="bg-white rounded-[10px] overflow-hidden">
          {/* Header */}
          <div className="p-4 flex flex-col md:flex-row md:items-center justify-between gap-3 border-b border-gray-100">
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2 text-orange-600 italic font-black text-xl md:text-2xl uppercase tracking-tighter">
                <Zap className="w-7 h-7 fill-orange-500 animate-pulse" />
                <span>Flash Sale</span>
              </div>
              
              {/* Countdown Timer (Giả lập visual, cần logic JS để chạy ngược thực tế) */}
              <div className="flex items-center gap-1 text-sm font-bold text-gray-800 bg-gray-100 px-3 py-1 rounded-full">
                <Clock className="w-4 h-4" />
                <span>Kết thúc trong: </span>
                <span className="bg-gray-800 text-white px-1.5 rounded">02</span> :
                <span className="bg-gray-800 text-white px-1.5 rounded">15</span> :
                <span className="bg-gray-800 text-white px-1.5 rounded">30</span>
              </div>
            </div>
            <a href="#" className="text-xs md:text-sm text-gray-500 hover:text-orange-600 font-medium flex items-center">
                Xem tất cả <span className="ml-1">›</span>
            </a>
          </div>
          
          {/* List */}
          <div className="p-2 md:p-4 bg-orange-50/30">
            {loading ? (
                <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                    {[...Array(5)].map((_, i) => (
                        <div key={i} className="h-[280px] bg-gray-200 rounded-lg animate-pulse"></div>
                    ))}
                </div>
            ) : (
                <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-5 gap-2 md:gap-3">
                    {products.map(p => (
                        <ProductCard key={p.id} product={p} />
                    ))}
                </div>
            )}
          </div>
      </div>
    </section>
  );
}
