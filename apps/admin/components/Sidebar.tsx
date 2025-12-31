"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { 
  LayoutDashboard, Package, ShoppingCart, Users, 
  ChevronDown, ChevronRight, Settings, FileText, Truck 
} from "lucide-react";

export default function Sidebar() {
  const pathname = usePathname();
  const [openGroups, setOpenGroups] = useState<string[]>(["product", "order"]);

  const toggleGroup = (key: string) => {
    if (openGroups.includes(key)) {
      setOpenGroups(openGroups.filter((g) => g !== key));
    } else {
      setOpenGroups([...openGroups, key]);
    }
  };

  const isActive = (path: string) => pathname === path;

  const menuItems = [
    {
      key: "dashboard",
      label: "Tổng quan",
      icon: <LayoutDashboard size={18} />,
      href: "/",
    },
    {
      key: "product",
      label: "Quản Lý Sản Phẩm",
      icon: <Package size={18} />,
      children: [
        { label: "Tất Cả Sản Phẩm", href: "/products" },
        { label: "Thêm Sản Phẩm", href: "/products/create" },
        { label: "Cài Đặt Sản Phẩm", href: "/products/settings" },
      ],
    },
    {
      key: "order",
      label: "Quản Lý Đơn Hàng",
      icon: <ShoppingCart size={18} />,
      children: [
        { label: "Tất Cả", href: "/orders" },
        { label: "Đơn Hủy", href: "/orders/cancel" },
        { label: "Trả Hàng/Hoàn Tiền", href: "/orders/return" },
      ],
    },
    {
      key: "user",
      label: "Khách Hàng",
      icon: <Users size={18} />,
      href: "/users",
    },
  ];

  return (
    <aside className="w-64 bg-white border-r h-screen fixed left-0 top-0 overflow-y-auto z-50 text-sm">
      <div className="h-14 flex items-center px-4 border-b">
        <span className="text-xl font-bold text-yellow-600">Lica Admin</span>
      </div>
      
      <div className="py-4">
        {menuItems.map((item) => (
          <div key={item.key} className="mb-1">
            {item.children ? (
              // Có menu con
              <div>
                <button
                  onClick={() => toggleGroup(item.key)}
                  className="w-full flex items-center justify-between px-4 py-3 text-gray-700 hover:bg-gray-50 font-medium"
                >
                  <div className="flex items-center gap-3">
                    {item.icon}
                    <span>{item.label}</span>
                  </div>
                  {openGroups.includes(item.key) ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
                </button>
                
                {openGroups.includes(item.key) && (
                  <div className="bg-gray-50/50 py-1">
                    {item.children.map((child) => (
                      <Link
                        key={child.href}
                        href={child.href}
                        className={`block pl-12 pr-4 py-2 hover:text-yellow-600 transition-colors ${
                          isActive(child.href) ? "text-yellow-600 font-medium" : "text-gray-500"
                        }`}
                      >
                        {child.label}
                      </Link>
                    ))}
                  </div>
                )}
              </div>
            ) : (
              // Không có menu con
              <Link
                href={item.href}
                className={`flex items-center gap-3 px-4 py-3 hover:bg-gray-50 ${
                  isActive(item.href) ? "text-yellow-600 bg-yellow-50 font-medium border-r-2 border-yellow-600" : "text-gray-700"
                }`}
              >
                {item.icon}
                <span>{item.label}</span>
              </Link>
            )}
          </div>
        ))}
      </div>
    </aside>
  );
}
