import Link from "next/link";
import { getImageUrl } from "@/lib/axios";
import { Product } from "@/services/product.service";
import { Star, Zap } from "lucide-react";

export default function ProductCard({ product }: { product: Product }) {
  // 1. Xử lý ảnh
  let mainImage = null;
  if (product.images) {
    if (Array.isArray(product.images) && product.images.length > 0) mainImage = product.images[0];
    else if (typeof product.images === 'string') {
        try { mainImage = JSON.parse(product.images)[0]; } catch { mainImage = product.images; }
    }
  }
  const imageUrl = getImageUrl(mainImage);
  
  // 2. Xử lý giá (Backend đã tính sẵn sale_price theo thứ tự ưu tiên)
  const originalPrice = product.price;
  const currentPrice = product.sale_price || originalPrice;
  const hasDiscount = product.has_discount;
  const discountPercent = hasDiscount ? Math.round(((originalPrice - currentPrice) / originalPrice) * 100) : 0;
  
  // 3. Kiểm tra loại giảm giá để hiện badge
  const isFlashSale = product.discount_info?.type === 'flash_sale';

  return (
    <div className="bg-white p-3 rounded-lg hover:shadow-lg transition-all duration-300 border border-transparent hover:border-lica-primary/20 h-full flex flex-col group relative">
      
      {/* Badge Giảm giá */}
      {hasDiscount && (
        <span className={`absolute top-0 right-0 text-white text-[10px] font-bold px-2 py-1 rounded-bl-lg z-10 ${isFlashSale ? 'bg-orange-500' : 'bg-lica-red'}`}>
          {isFlashSale && <Zap className="w-3 h-3 inline mr-1 fill-white"/>}
          -{discountPercent}%
        </span>
      )}
      
      <Link href={`/product/${product.id}`} className="relative block aspect-square mb-3 overflow-hidden rounded-md">
        <img 
            src={imageUrl}
            alt={product.name}
            className="object-cover w-full h-full transition-transform duration-500 group-hover:scale-110 mix-blend-multiply"
            loading="lazy"
        />
      </Link>

      <div className="flex-1 flex flex-col">
        {/* Giá bán hiện tại */}
        <div className="flex items-center gap-2 mb-1">
            <span className={`font-bold text-base ${isFlashSale ? 'text-orange-600' : 'text-lica-red'}`}>
                {currentPrice.toLocaleString('vi-VN')} ₫
            </span>
            {isFlashSale && <img src="https://media.hcdn.vn/hsk/icon/flash-sale.png" className="h-4" alt="FS"/>}
        </div>
        
        {/* Giá gốc (gạch ngang) */}
        {hasDiscount && (
           <div className="text-gray-400 text-xs line-through mb-1">
             {originalPrice.toLocaleString('vi-VN')} ₫
           </div>
        )}
        
        <Link href={`/product/${product.id}`} className="text-xs md:text-sm text-gray-700 line-clamp-2 mb-2 group-hover:text-lica-primary flex-1 min-h-[40px]" title={product.name}>
          {product.name}
        </Link>

        <div className="flex items-center gap-1 text-[10px] text-gray-500 mt-auto">
            <div className="flex text-lica-yellow">
                <Star className="w-3 h-3 fill-current" />
                <span className="ml-1 text-gray-600 font-bold">5.0</span>
            </div>
            <span className="ml-auto">Đã bán 100+</span>
        </div>
        
        {/* Progress Bar cho Flash Sale */}
        {isFlashSale && (
            <div className="mt-2 relative h-4 bg-orange-100 rounded-full overflow-hidden">
                <div className="absolute top-0 left-0 h-full bg-orange-500 w-[60%]"></div>
                <span className="absolute inset-0 flex items-center justify-center text-[9px] text-white font-bold uppercase drop-shadow-sm">
                    Đang bán chạy
                </span>
            </div>
        )}
      </div>
    </div>
  );
}
