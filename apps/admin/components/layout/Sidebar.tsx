'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import {
  LayoutDashboard,
  ShoppingBag,
  Package,
  Users,
  Settings,
  LogOut,
  Image as ImageIcon,
  Ticket,
  Tag,
  Zap, // Icon Flash Sale
} from 'lucide-react';

export default function Sidebar() {
  const pathname = usePathname();

  const menuItems = [
    { name: 'Dashboard', href: '/', icon: LayoutDashboard },
    { name: 'Đơn hàng', href: '/orders', icon: ShoppingBag },
    { name: 'Sản phẩm', href: '/products', icon: Package },
    { name: 'Khách hàng', href: '/users', icon: Users },
    { name: 'Flash Sale', href: '/marketing/flash-sales', icon: Zap }, // Mới
    { name: 'Chương trình KM', href: '/marketing/promotions', icon: Tag },
    { name: 'Mã giảm giá', href: '/marketing/coupons', icon: Ticket },
    { name: 'CMS & Media', href: '/cms', icon: ImageIcon },
    { name: 'Cài đặt', href: '/settings', icon: Settings },
  ];

  return (
    <div className="w-64 bg-white h-screen border-r border-gray-200 flex flex-col fixed left-0 top-0 z-50">
      <div className="h-16 flex items-center justify-center border-b border-gray-200 bg-white">
        <h1 className="text-xl font-bold text-blue-600">Lica Admin</h1>
      </div>

      <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
        {menuItems.map((item) => {
          const isActive = pathname === item.href || (item.href !== '/' && pathname.startsWith(item.href));
          const Icon = item.icon;
          const isFlashSale = item.href.includes('flash-sales');
          
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-3 py-2 rounded-md transition-colors font-medium text-sm ${
                isActive 
                  ? (isFlashSale ? 'bg-orange-50 text-orange-600' : 'bg-blue-50 text-blue-600')
                  : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
              }`}
            >
              <Icon className={`w-5 h-5 ${isFlashSale && isActive ? 'fill-orange-600' : ''}`} />
              <span>{item.name}</span>
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-gray-200 bg-gray-50">
        <button className="flex items-center gap-3 px-3 py-2 text-red-600 hover:bg-red-50 rounded-md w-full transition-colors text-sm font-medium">
          <LogOut className="w-5 h-5" />
          <span>Đăng xuất</span>
        </button>
      </div>
    </div>
  );
}
