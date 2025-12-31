#!/bin/bash

ADMIN_DIR="/var/www/lica-project/apps/admin"
COMP_DIR="$ADMIN_DIR/components"
APP_DIR="$ADMIN_DIR/app/products"

echo ">>> BẮT ĐẦU HOÀN THIỆN TÍNH NĂNG ADMIN..."

# ====================================================
# 1. CẬP NHẬT SIDEBAR (THÊM MENU MASTER DATA)
# ====================================================
echo ">>> [1/4] Updating Sidebar Menu..."
mkdir -p "$COMP_DIR"

cat > "$ADMIN_DIR/components/Sidebar.tsx" <<TSX
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState } from "react";
import { 
  LayoutDashboard, Package, ShoppingCart, Users, 
  ChevronDown, ChevronRight, Tag, Globe, Scale, Droplets
} from "lucide-react";

export default function Sidebar() {
  const pathname = usePathname();
  // Mở sẵn menu Product
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
        { label: "---", href: "#" }, // Separator
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

# ====================================================
# 2. TẠO COMPONENT CRUD CHUNG (GenericCrud)
# ====================================================
# Component này giúp tái sử dụng logic cho Brand, Origin, Unit...
echo ">>> [2/4] Creating Generic CRUD Component..."
cat > "$COMP_DIR/GenericCrud.tsx" <<TSX
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { Plus, Trash2, Edit, Loader2, Save, X } from "lucide-react";

interface Item {
  id: number;
  name: string;
  code?: string; // Cho Origin/SkinType
  slug?: string; // Cho Brand
}

interface Props {
  title: string;
  endpoint: string; // ví dụ: "brands"
  hasCode?: boolean; // Có cột mã code không?
}

export default function GenericCrud({ title, endpoint, hasCode = false }: Props) {
  const [data, setData] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<Item | null>(null);
  const [formName, setFormName] = useState("");
  const [formCode, setFormCode] = useState("");

  const apiUrl = \`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/\${endpoint}\`;

  const fetchData = async () => {
    try {
      setLoading(true);
      const res = await axios.get(apiUrl);
      setData(res.data.data || []);
    } catch (err) { console.error(err); } 
    finally { setLoading(false); }
  };

  useEffect(() => { fetchData(); }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    try {
      const payload = { name: formName, ...(hasCode && { code: formCode }) };
      if (editingItem) {
        await axios.put(\`\${apiUrl}/\${editingItem.id}\`, payload);
      } else {
        await axios.post(apiUrl, payload);
      }
      setModalOpen(false);
      resetForm();
      fetchData();
    } catch (err) { alert("Có lỗi xảy ra!"); }
  };

  const handleDelete = async (id: number) => {
    if (!confirm("Bạn chắc chắn muốn xóa?")) return;
    try {
      await axios.delete(\`\${apiUrl}/\${id}\`);
      fetchData();
    } catch (err) { alert("Không thể xóa (có thể đang được sử dụng)."); }
  };

  const openEdit = (item: Item) => {
    setEditingItem(item);
    setFormName(item.name);
    setFormCode(item.code || "");
    setModalOpen(true);
  };

  const resetForm = () => {
    setEditingItem(null);
    setFormName("");
    setFormCode("");
  };

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Quản lý {title}</h1>
        <button onClick={() => { resetForm(); setModalOpen(true); }} className="bg-blue-600 text-white px-4 py-2 rounded-md flex items-center gap-2 hover:bg-blue-700">
          <Plus size={18} /> Thêm mới
        </button>
      </div>

      <div className="bg-white rounded-lg shadow border overflow-hidden">
        {loading ? (
          <div className="p-8 flex justify-center"><Loader2 className="animate-spin text-blue-600"/></div>
        ) : (
          <table className="w-full text-sm text-left">
            <thead className="bg-gray-50 text-gray-700 uppercase font-medium">
              <tr>
                <th className="px-6 py-3">ID</th>
                <th className="px-6 py-3">Tên hiển thị</th>
                {hasCode && <th className="px-6 py-3">Mã (Code)</th>}
                <th className="px-6 py-3 text-right">Hành động</th>
              </tr>
            </thead>
            <tbody>
              {data.map((item) => (
                <tr key={item.id} className="border-b hover:bg-gray-50">
                  <td className="px-6 py-4">{item.id}</td>
                  <td className="px-6 py-4 font-medium text-gray-900">{item.name}</td>
                  {hasCode && <td className="px-6 py-4 font-mono text-gray-500">{item.code || '-'}</td>}
                  <td className="px-6 py-4 text-right flex justify-end gap-3">
                    <button onClick={() => openEdit(item)} className="text-blue-600 hover:underline"><Edit size={16}/></button>
                    <button onClick={() => handleDelete(item.id)} className="text-red-600 hover:underline"><Trash2 size={16}/></button>
                  </td>
                </tr>
              ))}
              {data.length === 0 && <tr><td colSpan={4} className="p-6 text-center text-gray-500">Chưa có dữ liệu</td></tr>}
            </tbody>
          </table>
        )}
      </div>

      {/* MODAL */}
      {modalOpen && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
          <div className="bg-white p-6 rounded-lg w-96 shadow-xl animate-in fade-in zoom-in duration-200">
            <h3 className="text-lg font-bold mb-4">{editingItem ? "Cập nhật" : "Thêm mới"} {title}</h3>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1">Tên {title}</label>
                <input required value={formName} onChange={e => setFormName(e.target.value)} className="w-full border p-2 rounded focus:ring-2 ring-blue-500 outline-none" placeholder="Nhập tên..." />
              </div>
              {hasCode && (
                <div>
                  <label className="block text-sm font-medium mb-1">Mã (Code/Viết tắt)</label>
                  <input value={formCode} onChange={e => setFormCode(e.target.value)} className="w-full border p-2 rounded focus:ring-2 ring-blue-500 outline-none uppercase" placeholder="VN, KR, 50ML..." />
                </div>
              )}
              <div className="flex justify-end gap-2 mt-6">
                <button type="button" onClick={() => setModalOpen(false)} className="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded">Hủy</button>
                <button type="submit" className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 flex items-center gap-2">
                    <Save size={16}/> Lưu
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
TSX

# ====================================================
# 3. TẠO CÁC TRANG QUẢN LÝ (SỬ DỤNG GENERIC CRUD)
# ====================================================
echo ">>> [3/4] Generating Management Pages..."

create_crud_page() {
    FOLDER=$1
    TITLE=$2
    ENDPOINT=$3
    HAS_CODE=$4
    mkdir -p "$APP_DIR/$FOLDER"
    
    cat > "$APP_DIR/$FOLDER/page.tsx" <<TSX
import GenericCrud from "@/components/GenericCrud";
export default function Page() {
  return <GenericCrud title="$TITLE" endpoint="$ENDPOINT" hasCode={$HAS_CODE} />;
}
TSX
}

create_crud_page "brands" "Thương Hiệu" "brands" "false"
create_crud_page "origins" "Xuất Xứ" "origins" "true"
create_crud_page "units" "Đơn Vị Tính" "units" "false"
create_crud_page "skin-types" "Loại Da" "skin-types" "false"

# ====================================================
# 4. FIX TRANG LIST PRODUCT (SỬA LỖI EXCEPTION)
# ====================================================
echo ">>> [4/4] Fixing Product List Page..."

cat > "$ADMIN_DIR/app/products/page.tsx" <<TSX
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import Link from "next/link";
import { Plus, Search, Edit, Trash2, Loader2, ImageOff } from "lucide-react";

export default function ProductList() {
  const [products, setProducts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState("");

  const fetchProducts = async () => {
    try {
      setLoading(true);
      const res = await axios.get(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/product\`);
      setProducts(res.data.data?.data || []); // Laravel paginate trả về object {data: []}
    } catch (err) { 
      console.error(err); 
      setProducts([]); // Fallback nếu lỗi
    } finally { setLoading(false); }
  };

  useEffect(() => { fetchProducts(); }, []);

  const handleDelete = async (id: number) => {
    if (!confirm("Xóa sản phẩm này?")) return;
    try {
      await axios.delete(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/\${id}\`);
      fetchProducts();
    } catch (err) { alert("Lỗi xóa sản phẩm"); }
  };

  // Filter local đơn giản
  const filteredProducts = products.filter(p => 
    p.name?.toLowerCase().includes(searchTerm.toLowerCase()) || 
    p.sku?.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Danh sách sản phẩm</h1>
        <Link href="/products/create" className="bg-blue-600 text-white px-4 py-2 rounded-md flex items-center gap-2 hover:bg-blue-700 shadow">
          <Plus size={18} /> Thêm sản phẩm
        </Link>
      </div>

      {/* Toolbar */}
      <div className="mb-4 flex gap-4">
        <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
            <input 
                type="text" 
                placeholder="Tìm kiếm theo tên, SKU..." 
                className="w-full pl-10 pr-4 py-2 border rounded-md focus:ring-2 ring-blue-500 outline-none"
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
            />
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-lg shadow border overflow-hidden">
        <table className="w-full text-sm text-left">
            <thead className="bg-gray-50 text-gray-700 uppercase font-medium">
                <tr>
                    <th className="px-4 py-3 w-16">Hình</th>
                    <th className="px-4 py-3">Tên sản phẩm / SKU</th>
                    <th className="px-4 py-3">Giá bán</th>
                    <th className="px-4 py-3">Kho</th>
                    <th className="px-4 py-3">Thương hiệu</th>
                    <th className="px-4 py-3 text-right">Hành động</th>
                </tr>
            </thead>
            <tbody>
                {loading ? (
                    <tr><td colSpan={6} className="p-8 text-center"><Loader2 className="animate-spin inline text-blue-600"/> Đang tải...</td></tr>
                ) : filteredProducts.length > 0 ? (
                    filteredProducts.map((p) => (
                        <tr key={p.id} className="border-b hover:bg-gray-50">
                            <td className="px-4 py-3">
                                {p.thumbnail ? (
                                    <img src={p.thumbnail} alt="" className="w-10 h-10 object-cover rounded border" />
                                ) : (
                                    <div className="w-10 h-10 bg-gray-100 rounded flex items-center justify-center text-gray-400"><ImageOff size={16}/></div>
                                )}
                            </td>
                            <td className="px-4 py-3">
                                <div className="font-medium text-gray-900">{p.name}</div>
                                <div className="text-xs text-gray-500 font-mono">{p.sku || "_"}</div>
                            </td>
                            <td className="px-4 py-3 font-medium text-green-600">
                                {new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(p.price)}
                            </td>
                            <td className="px-4 py-3">
                                <span className={\`px-2 py-1 rounded text-xs \${p.stock_quantity > 0 ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}\`}>
                                    {p.stock_quantity}
                                </span>
                            </td>
                            <td className="px-4 py-3 text-gray-600">
                                {p.brand?.name || "-"}
                            </td>
                            <td className="px-4 py-3 text-right">
                                <div className="flex justify-end gap-2">
                                    <Link href={\`/products/\${p.id}\`} className="text-blue-600 hover:bg-blue-50 p-1 rounded"><Edit size={16}/></Link>
                                    <button onClick={() => handleDelete(p.id)} className="text-red-600 hover:bg-red-50 p-1 rounded"><Trash2 size={16}/></button>
                                </div>
                            </td>
                        </tr>
                    ))
                ) : (
                    <tr><td colSpan={6} className="p-8 text-center text-gray-500">Không tìm thấy sản phẩm nào.</td></tr>
                )}
            </tbody>
        </table>
      </div>
    </div>
  );
}
TSX

# ====================================================
# 5. REBUILD FRONTEND
# ====================================================
echo ">>> Rebuilding Next.js..."
cd "$ADMIN_DIR"
npm run build
pm2 restart lica-admin 2>/dev/null

echo "--------------------------------------------------------"
echo "✅ ĐÃ NÂNG CẤP XONG!"
echo "👉 F5 trang Admin. Bạn sẽ thấy:"
echo "   1. Menu 'Sản phẩm' có thêm các mục quản lý con."
echo "   2. Trang /products hết lỗi client-side."
echo "   3. Có thể bấm vào 'Thương hiệu' để thêm mới dữ liệu."
echo "--------------------------------------------------------"
