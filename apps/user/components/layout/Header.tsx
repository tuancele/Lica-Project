'use client'; // Chuyển thành client component để dùng useCart

import Link from 'next/link';
import { Search, ShoppingCart, User, MapPin, Phone } from 'lucide-react';
import { useCart } from '@/context/CartContext';

export default function Header() {
  const { count } = useCart();

  return (
    <header className="bg-white sticky top-0 z-50 shadow-sm">
      {/* Top Banner Green */}
      <div className="bg-lica-primary h-[36px] hidden md:block">
        <div className="container-custom h-full flex items-center justify-end text-white text-[11px] gap-6">
           <Link href="#" className="hover:opacity-80 flex items-center gap-1">
             <Phone className="w-3 h-3" /> Hỗ trợ khách hàng
           </Link>
           <Link href="#" className="hover:opacity-80">Tải ứng dụng</Link>
        </div>
      </div>

      {/* Main Header */}
      <div className="container-custom py-3 md:py-4">
        <div className="flex items-center gap-4 md:gap-8">
          {/* Logo */}
          <Link href="/" className="flex-shrink-0 flex flex-col items-center">
            <div className="text-2xl md:text-3xl font-extrabold text-lica-primary tracking-tighter leading-none">
              LICA.VN
            </div>
            <div className="text-[8px] md:text-[10px] text-lica-primary tracking-[0.2em] font-medium">
              BEAUTY & CLINIC
            </div>
          </Link>

          {/* Search Bar */}
          <div className="flex-1 relative max-w-2xl">
            <div className="relative">
              <input 
                type="text" 
                placeholder="Tìm sản phẩm, thương hiệu, ..." 
                className="w-full h-10 pl-4 pr-12 border-2 border-lica-primary/20 rounded-md focus:outline-none focus:border-lica-primary text-sm"
              />
              <button className="absolute right-0 top-0 h-10 w-14 bg-lica-primary flex items-center justify-center rounded-r-md hover:bg-opacity-90 transition-colors">
                <Search className="w-5 h-5 text-white" />
              </button>
            </div>
          </div>

          {/* Actions */}
          <div className="flex items-center gap-3 md:gap-6 text-[11px] md:text-xs font-medium text-gray-700">
            <Link href="/login" className="flex flex-col items-center gap-1 hover:text-lica-primary group">
              <div className="p-1.5 rounded-full bg-gray-100 group-hover:bg-lica-primary/10 transition-colors">
                <User className="w-5 h-5 md:w-6 md:h-6 text-gray-600 group-hover:text-lica-primary" />
              </div>
              <span className="hidden md:block">Tài khoản</span>
            </Link>

            <Link href="/cart" className="flex flex-col items-center gap-1 hover:text-lica-primary group relative">
              <div className="p-1.5 rounded-full bg-gray-100 group-hover:bg-lica-primary/10 transition-colors relative">
                <ShoppingCart className="w-5 h-5 md:w-6 md:h-6 text-gray-600 group-hover:text-lica-primary" />
                {count > 0 && (
                    <span className="absolute -top-1 -right-1 bg-lica-red text-white text-[10px] min-w-[16px] h-4 px-1 flex items-center justify-center rounded-full border-2 border-white">
                        {count}
                    </span>
                )}
              </div>
              <span className="hidden md:block">Giỏ hàng</span>
            </Link>
          </div>
        </div>
      </div>
    </header>
  );
}
