'use client';

import { Menu, ChevronDown } from 'lucide-react';
import Link from 'next/link';
import { useEffect, useState } from 'react';
import { ProductService, Category } from '@/services/product.service';

export default function Navigation() {
  const [categories, setCategories] = useState<Category[]>([]);

  useEffect(() => {
    const fetchCategories = async () => {
      const data = await ProductService.getCategories();
      setCategories(data);
    };
    fetchCategories();
  }, []);

  return (
    <div className="border-b border-gray-200 bg-white shadow-sm">
      <div className="container-custom">
        <div className="flex items-center h-[42px]">
          {/* Menu Button - Dropdown */}
          <div className="group relative h-full flex items-center bg-lica-primary px-4 text-white font-bold text-sm cursor-pointer w-[240px] uppercase select-none">
            <Menu className="w-5 h-5 mr-3" />
            <span>Danh mục</span>
            <ChevronDown className="w-4 h-4 ml-auto opacity-70" />
            
            {/* Dropdown Content */}
            <div className="absolute top-full left-0 w-[240px] bg-white shadow-xl border border-gray-100 hidden group-hover:block z-40 max-h-[450px] overflow-y-auto rounded-b-md">
              {categories.length > 0 ? (
                categories.map((cat) => (
                  <Link 
                    key={cat.id} 
                    href={`/category/${cat.id}`}
                    className="block px-4 py-2.5 text-sm text-gray-700 hover:bg-gray-50 hover:text-lica-primary border-b border-gray-50 last:border-0 transition-colors"
                  >
                    {cat.name}
                  </Link>
                ))
              ) : (
                <div className="px-4 py-3 text-xs text-gray-400 text-center">Đang tải danh mục...</div>
              )}
            </div>
          </div>

          {/* Quick Links Horizontal */}
          <div className="flex-1 flex items-center gap-6 ml-6 text-[13px] font-semibold text-gray-600 uppercase overflow-x-auto whitespace-nowrap scrollbar-hide h-full">
            <Link href="#" className="hover:text-lica-red text-lica-red flex items-center h-full border-b-2 border-transparent hover:border-lica-red transition-all">
                Hasaki Deals
            </Link>
            <Link href="#" className="hover:text-lica-primary flex items-center h-full border-b-2 border-transparent hover:border-lica-primary transition-all">
                Hàng Mới Về
            </Link>
            <Link href="#" className="hover:text-lica-primary flex items-center h-full border-b-2 border-transparent hover:border-lica-primary transition-all">
                Bán Chạy
            </Link>
            <Link href="#" className="hover:text-lica-primary flex items-center h-full border-b-2 border-transparent hover:border-lica-primary transition-all">
                Clinic & Spa
            </Link>
            <Link href="#" className="hover:text-lica-primary flex items-center h-full border-b-2 border-transparent hover:border-lica-primary transition-all">
                Tra Cứu Đơn Hàng
            </Link>
          </div>
        </div>
      </div>
    </div>
  );
}
