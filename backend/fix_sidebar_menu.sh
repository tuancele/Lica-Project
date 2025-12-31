#!/bin/bash

ADMIN_DIR="/var/www/lica-project/apps/admin"
SIDEBAR_FILE="$ADMIN_DIR/components/Sidebar.tsx"

echo ">>> ĐANG CẬP NHẬT MENU SIDEBAR..."

# Ghi đè lại file Sidebar.tsx với đầy đủ menu
cat > "$SIDEBAR_FILE" <<TSX
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { 
  LayoutDashboard, Package, ShoppingCart, Users, 
  ChevronDown, ChevronRight, Tag, Globe, Scale, Droplets, FolderTree
} from "lucide-react";

export default function Sidebar() {
  const pathname = usePathname();
  const [openGroups, setOpenGroups] = useState<string[]>(["product"]);

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
      label: "Sản Phẩm & Kho",
      icon: <Package size={18} />,
      children: [
        { label: "Tất Cả Sản Phẩm", href: "/products" },
        { label: "Thêm Mới", href: "/products/create" },
        { label: "---", href: "#" },
        // --- ĐÃ THÊM MỤC PHÂN LOẠI VÀO ĐÂY ---
        { label: "Phân loại (Category)", href: "/products/categories", icon: <FolderTree size={14}/> },
        { label: "Thương Hiệu", href: "/products/brands", icon: <Tag size={14}/> },
        { label: "Xuất Xứ", href: "/products/origins", icon: <Globe size={14}/> },
        { label: "Đơn Vị / Dung Tích", href: "/products/units", icon: <Scale size={14}/> },
        { label: "Loại Da", href: "/products/skin-types", icon: <Droplets size={14}/> },
      ],
    },
    {
      key: "order",
      label: "Đơn Hàng",
      icon: <ShoppingCart size={18} />,
      children: [
        { label: "Danh Sách Đơn", href: "/orders" },
        { label: "Xử Lý Trả Hàng", href: "/orders/return" },
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
    <aside className="w-64 bg-white border-r h-screen fixed left-0 top-0 overflow-y-auto z-50 text-sm shadow-sm font-sans">
      <div className="h-16 flex items-center justify-center border-b">
        <span className="text-2xl font-extrabold text-blue-600 tracking-tight">LICA<span className="text-gray-800">ADMIN</span></span>
      </div>
      
      <div className="py-4 px-2">
        {menuItems.map((item) => (
          <div key={item.key} className="mb-1">
            {item.children ? (
              <div className="bg-white rounded-lg overflow-hidden mb-1">
                <button
                  onClick={() => toggleGroup(item.key)}
                  className={\`w-full flex items-center justify-between px-3 py-2.5 text-gray-700 hover:bg-gray-50 font-medium rounded-md transition-colors \${openGroups.includes(item.key) ? 'bg-blue-50 text-blue-700' : ''}\`}
                >
                  <div className="flex items-center gap-3">
                    {item.icon}
                    <span>{item.label}</span>
                  </div>
                  {openGroups.includes(item.key) ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
                </button>
                
                {openGroups.includes(item.key) && (
                  <div className="pl-4 mt-1 space-y-0.5">
                    {item.children.map((child, idx) => (
                      child.label === '---' ? 
                      <div key={idx} className="border-t border-gray-100 my-2 mx-4"></div> :
                      <Link
                        key={child.href}
                        href={child.href}
                        className={\`flex items-center gap-2 px-3 py-2 rounded-md text-[13px] transition-colors \${
                          isActive(child.href) ? "text-blue-600 bg-blue-50 font-semibold" : "text-gray-500 hover:text-gray-900 hover:bg-gray-50"
                        }\`}
                      >
                        {child.icon && child.icon}
                        {child.label}
                      </Link>
                    ))}
                  </div>
                )}
              </div>
            ) : (
              <Link
                href={item.href}
                className={\`flex items-center gap-3 px-3 py-2.5 rounded-md transition-colors font-medium \${
                  isActive(item.href) ? "bg-blue-600 text-white shadow-md" : "text-gray-700 hover:bg-gray-100"
                }\`}
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
TSX

# Rebuild lại để cập nhật giao diện
echo ">>> Rebuilding Admin..."
cd "$ADMIN_DIR"
npm run build
pm2 restart lica-admin 2>/dev/null

echo "--------------------------------------------------------"
echo "✅ ĐÃ CẬP NHẬT MENU THÀNH CÔNG!"
echo "👉 Hãy F5 lại trang Admin, bạn sẽ thấy mục 'Phân loại (Category)'."
echo "--------------------------------------------------------"
