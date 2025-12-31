"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { 
  LayoutDashboard, ShoppingBag, Package, Users, Settings, 
  LogOut, Image as ImageIcon, Ticket, BarChart3 
} from "lucide-react";

export default function Sidebar() {
  const pathname = usePathname();

  const menuItems = [
    { name: "Tổng quan", href: "/", icon: <LayoutDashboard size={20} /> },
    { name: "Đơn hàng", href: "/orders", icon: <ShoppingBag size={20} /> },
    { name: "Sản phẩm", href: "/products", icon: <Package size={20} /> },
    { name: "Khách hàng", href: "/users", icon: <Users size={20} /> },
    
    // Group Marketing
    { section: "Kênh Marketing" },
    { name: "Mã giảm giá", href: "/marketing/coupons", icon: <Ticket size={20} /> },
    
    { section: "Hệ thống" },
    { name: "Cấu hình", href: "/settings", icon: <Settings size={20} /> },
  ];

  return (
    <div className="w-64 bg-white h-screen border-r border-gray-200 flex flex-col fixed left-0 top-0 z-50">
      <div className="p-6 border-b border-gray-100 flex items-center gap-3">
        <div className="w-8 h-8 bg-blue-600 rounded-lg flex items-center justify-center text-white font-bold">L</div>
        <span className="font-bold text-xl text-gray-800">Lica Admin</span>
      </div>

      <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
        {menuItems.map((item, index) => {
          if (item.section) {
            return (
                <div key={index} className="mt-6 mb-2 px-3 text-xs font-bold text-gray-400 uppercase tracking-wider">
                    {item.section}
                </div>
            );
          }

          const isActive = item.href === "/" 
            ? pathname === "/" 
            : pathname.startsWith(item.href || "");

          return (
            <Link
              key={index}
              href={item.href || "#"}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all duration-200 font-medium ${
                isActive
                  ? "bg-blue-50 text-blue-700 shadow-sm"
                  : "text-gray-600 hover:bg-gray-50 hover:text-gray-900"
              }`}
            >
              <div className={`${isActive ? "text-blue-600" : "text-gray-400"}`}>{item.icon}</div>
              {item.name}
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-gray-100">
        <button 
            onClick={() => {
                document.cookie = "admin_token=; path=/; expires=Thu, 01 Jan 1970 00:00:01 GMT;";
                window.location.href = "/login";
            }}
            className="flex items-center gap-3 w-full px-3 py-2.5 text-gray-600 hover:bg-red-50 hover:text-red-600 rounded-lg transition"
        >
          <LogOut size={20} />
          <span className="font-medium">Đăng xuất</span>
        </button>
      </div>
    </div>
  );
}
