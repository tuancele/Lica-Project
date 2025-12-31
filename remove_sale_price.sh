#!/bin/bash

echo "✂️ Đang gỡ bỏ trường 'Giá giảm' (Sale Price) khỏi hệ thống..."

# 1. CẬP NHẬT FORM SẢN PHẨM (Xóa input giá giảm & Chỉnh lại Grid)
cat << 'EOF' > /var/www/lica-project/apps/admin/components/ProductForm.tsx
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { Product, Category, Brand, Origin, Unit, SkinType } from "@/types/product";
import { 
  Save, Image as ImageIcon, Box, Tag, Plus, Loader2, 
  Droplets, FileText, Globe, Scale, Truck, Beaker, BookOpen
} from "lucide-react";

import { DndContext, closestCenter, KeyboardSensor, PointerSensor, useSensor, useSensors, DragEndEvent } from '@dnd-kit/core';
import { arrayMove, SortableContext, sortableKeyboardCoordinates, rectSortingStrategy } from '@dnd-kit/sortable';
import { SortableImage } from "./product/SortableImage";

interface Props { initialData?: Product; isEdit?: boolean; }

export default function ProductForm({ initialData, isEdit = false }: Props) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [isUploading, setIsUploading] = useState(false);

  const [categories, setCategories] = useState<Category[]>([]);
  const [brands, setBrands] = useState<Brand[]>([]);
  const [origins, setOrigins] = useState<Origin[]>([]);
  const [units, setUnits] = useState<Unit[]>([]);
  const [skinTypesList, setSkinTypesList] = useState<SkinType[]>([]);

  const [formData, setFormData] = useState<Partial<Product>>(
    initialData || {
      name: "", sku: "", price: 0, sale_price: 0, stock_quantity: 0,
      weight: 0, length: 0, width: 0, height: 0,
      category_id: null, brand_id: null, origin_id: null, unit_id: null,
      skin_type_ids: [], short_description: "", description: "", 
      ingredients: "", usage_instructions: "", images: [], is_active: true
    }
  );

  useEffect(() => {
    const fetchData = async () => {
      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        const [catRes, brandRes, originRes, unitRes, skinRes] = await Promise.all([
          axios.get(`${apiUrl}/api/v1/category`),
          axios.get(`${apiUrl}/api/v1/product/brands`),
          axios.get(`${apiUrl}/api/v1/product/origins`),
          axios.get(`${apiUrl}/api/v1/product/units`),
          axios.get(`${apiUrl}/api/v1/product/skin-types`)
        ]);
        setCategories(catRes.data.data || []);
        setBrands(brandRes.data.data || []);
        setOrigins(originRes.data.data || []);
        setUnits(unitRes.data.data || []);
        setSkinTypesList(skinRes.data.data || []);
      } catch (err) { console.error(err); }
    };
    fetchData();
  }, []);

  const sensors = useSensors(useSensor(PointerSensor), useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }));

  const toggleSkinType = (id: number) => {
    const currentIds = formData.skin_type_ids || [];
    setFormData({ 
      ...formData, 
      skin_type_ids: currentIds.includes(id) ? currentIds.filter(x => x !== id) : [...currentIds, id] 
    });
  };

  const handleMultiUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files) return;
    const files = Array.from(e.target.files);
    const remainingSlots = 9 - (formData.images?.length || 0);
    const filesToUpload = files.slice(0, remainingSlots);
    if (filesToUpload.length === 0) return;

    setIsUploading(true);
    const uploadedUrls: string[] = [...(formData.images || [])];

    for (const file of filesToUpload) {
      const data = new FormData();
      data.append("file", file);
      try {
        const res = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/cms/upload`, data);
        uploadedUrls.push(res.data.url);
        setFormData(prev => ({ ...prev, images: [...uploadedUrls] }));
      } catch (error) { console.error("Lỗi upload", file.name); }
    }
    setIsUploading(false);
  };

  const handleDragEnd = (event: DragEndEvent) => {
    const { active, over } = event;
    if (over && active.id !== over.id) {
      const oldIndex = formData.images!.indexOf(active.id as string);
      const newIndex = formData.images!.indexOf(over.id as string);
      setFormData(prev => ({ ...prev, images: arrayMove(prev.images!, oldIndex, newIndex) }));
    }
  };

  const removeImage = (index: number) => {
    const newImages = [...(formData.images || [])];
    newImages.splice(index, 1);
    setFormData({ ...formData, images: newImages });
  };

  const handleChange = (field: keyof Product, value: any) => setFormData({ ...formData, [field]: value });
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    try {
      if (isEdit && initialData) await axios.put(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/${initialData.id}`, formData);
      else await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product`, formData);
      router.push("/products");
    } catch (error: any) { alert("Lỗi lưu sản phẩm"); } finally { setLoading(false); }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6 pb-24 max-w-5xl mx-auto font-sans">
      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><Tag size={20} className="text-blue-600" /> Thông tin cơ bản</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="md:col-span-2"><label className="block text-sm font-bold text-gray-700 mb-1">Tên sản phẩm *</label>
            <input type="text" required className="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-blue-500 outline-none" value={formData.name || ""} onChange={(e) => handleChange("name", e.target.value)} />
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Danh mục *</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2.5 bg-white focus:ring-2 focus:ring-blue-500 outline-none" value={formData.category_id || ""} onChange={(e) => handleChange("category_id", e.target.value)} required >
              <option value="">-- Chọn danh mục --</option>
              {categories.map((cat: any) => (<option key={cat.id} value={cat.id}>{"⠀⠀".repeat(cat.level)}{cat.level === 0 ? "🟦 " : "└─ "}{cat.name}</option>))}
            </select>
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Thương hiệu</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2.5 bg-white focus:ring-2 focus:ring-blue-500 outline-none" value={formData.brand_id || ""} onChange={(e) => handleChange("brand_id", e.target.value)}>
              <option value="">-- Chọn thương hiệu --</option>{brands.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}
            </select>
          </div>
        </div>
      </div>

      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><Droplets size={20} className="text-pink-500" /> Đặc tính mỹ phẩm</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Xuất xứ</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2.5 bg-white" value={formData.origin_id || ""} onChange={(e) => handleChange("origin_id", e.target.value)}>
              <option value="">-- Chọn quốc gia --</option>{origins.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
            </select>
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Dung tích / Đơn vị</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2.5 bg-white" value={formData.unit_id || ""} onChange={(e) => handleChange("unit_id", e.target.value)}>
              <option value="">-- Chọn đơn vị --</option>{units.map(u => <option key={u.id} value={u.id}>{u.name}</option>)}
            </select>
          </div>
        </div>
        <div>
          <label className="block text-sm font-bold text-gray-700 mb-2">Loại da phù hợp</label>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3 bg-gray-50 p-4 rounded-xl border border-gray-100">
            {skinTypesList.map(type => (
              <label key={type.id} className="flex items-center space-x-2 cursor-pointer p-2 hover:bg-white rounded-lg transition">
                <input type="checkbox" className="w-4 h-4 text-pink-600 rounded border-gray-300 focus:ring-pink-500" checked={formData.skin_type_ids?.includes(type.id) || false} onChange={() => toggleSkinType(type.id)} />
                <span className="text-sm text-gray-600">{type.name}</span>
              </label>
            ))}
          </div>
        </div>
      </div>

      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><FileText size={20} className="text-orange-500" /> Nội dung</h3>
        <div className="space-y-4">
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Mô tả ngắn</label>
            <textarea className="w-full border border-gray-300 rounded-lg px-3 py-2 h-16 outline-none focus:ring-2 focus:ring-orange-500" value={formData.short_description || ""} onChange={(e) => handleChange("short_description", e.target.value)} />
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Mô tả chi tiết</label>
            <textarea className="w-full border border-gray-300 rounded-lg px-3 py-2 h-40 outline-none focus:ring-2 focus:ring-orange-500" value={formData.description || ""} onChange={(e) => handleChange("description", e.target.value)} />
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div><label className="block text-sm font-bold text-gray-700 mb-1"><Beaker size={14}/> Thành phần</label>
              <textarea className="w-full border border-gray-300 rounded-lg px-3 py-2 h-24 outline-none focus:ring-2 focus:ring-orange-500 font-mono text-xs" value={formData.ingredients || ""} onChange={(e) => handleChange("ingredients", e.target.value)} />
            </div>
            <div><label className="block text-sm font-bold text-gray-700 mb-1"><BookOpen size={14}/> Hướng dẫn sử dụng</label>
              <textarea className="w-full border border-gray-300 rounded-lg px-3 py-2 h-24 outline-none focus:ring-2 focus:ring-orange-500" value={formData.usage_instructions || ""} onChange={(e) => handleChange("usage_instructions", e.target.value)} />
            </div>
          </div>
        </div>
      </div>

      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><Box size={20} className="text-green-600" /> Giá & Kho vận</h3>
        {/* ĐÃ XÓA GIÁ GIẢM VÀ ĐỔI GRID THÀNH 3 CỘT */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Giá bán</label>
            <input type="number" className="w-full border border-gray-300 rounded-lg px-3 py-2" value={formData.price || 0} onChange={(e) => handleChange("price", e.target.value)} />
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Số lượng</label>
            <input type="number" className="w-full border border-gray-300 rounded-lg px-3 py-2" value={formData.stock_quantity || 0} onChange={(e) => handleChange("stock_quantity", e.target.value)} />
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Mã SKU</label>
            <input type="text" className="w-full border border-gray-300 rounded-lg px-3 py-2 uppercase font-mono" value={formData.sku || ""} onChange={(e) => handleChange("sku", e.target.value)} />
          </div>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4 pt-4 border-t border-gray-50">
          <div><label className="text-[10px] font-bold text-gray-400 uppercase">Cân nặng(g)</label>
            <input type="number" className="w-full border border-gray-200 rounded-lg px-2 py-1" value={formData.weight || 0} onChange={(e) => handleChange("weight", e.target.value)} />
          </div>
          <div><label className="text-[10px] font-bold text-gray-400 uppercase">Dài(cm)</label>
            <input type="number" className="w-full border border-gray-200 rounded-lg px-2 py-1" value={formData.length || 0} onChange={(e) => handleChange("length", e.target.value)} />
          </div>
          <div><label className="text-[10px] font-bold text-gray-400 uppercase">Rộng(cm)</label>
            <input type="number" className="w-full border border-gray-200 rounded-lg px-2 py-1" value={formData.width || 0} onChange={(e) => handleChange("width", e.target.value)} />
          </div>
          <div><label className="text-[10px] font-bold text-gray-400 uppercase">Cao(cm)</label>
            <input type="number" className="w-full border border-gray-200 rounded-lg px-2 py-1" value={formData.height || 0} onChange={(e) => handleChange("height", e.target.value)} />
          </div>
        </div>
      </div>

      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-4 flex items-center gap-2"><ImageIcon size={20} className="text-purple-600" /> Hình ảnh ({formData.images?.length || 0}/9)</h3>
        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <SortableContext items={formData.images || []} strategy={rectSortingStrategy}>
            <div className="flex flex-wrap gap-4 min-h-[120px] p-4 bg-gray-50 rounded-2xl border-2 border-dashed border-gray-200">
              {formData.images?.map((url, index) => (
                <SortableImage key={url} id={url} url={url} index={index} onRemove={removeImage} />
              ))}
              {(formData.images?.length || 0) < 9 && !isUploading && (
                <label className="w-28 h-28 border-2 border-dashed border-gray-300 rounded-xl flex flex-col items-center justify-center text-gray-400 hover:border-blue-500 hover:text-blue-500 cursor-pointer transition bg-white hover:bg-blue-50">
                  <Plus size={24} />
                  <span className="text-[10px] font-bold mt-1">THÊM ẢNH</span>
                  <input type="file" multiple accept="image/*" className="hidden" onChange={handleMultiUpload} />
                </label>
              )}
              {isUploading && (
                <div className="w-28 h-28 border-2 border-dashed border-blue-200 rounded-xl flex flex-col items-center justify-center text-blue-400 bg-blue-50 animate-pulse">
                  <Loader2 className="animate-spin" size={24} />
                  <span className="text-[10px] font-bold mt-1 uppercase">Đang tải...</span>
                </div>
              )}
            </div>
          </SortableContext>
        </DndContext>
      </div>

      <div className="fixed bottom-0 right-0 left-64 bg-white/80 backdrop-blur-md border-t p-4 flex justify-end gap-3 z-50 shadow-lg">
        <button type="button" onClick={() => router.back()} className="px-8 py-2.5 rounded-xl font-bold text-gray-500 hover:bg-gray-100 transition">HỦY BỎ</button>
        <button type="submit" disabled={loading || isUploading} className="px-12 py-2.5 rounded-xl font-bold bg-blue-600 text-white hover:bg-blue-700 shadow-lg transition flex items-center gap-2">
          {loading ? <Loader2 className="animate-spin" size={18}/> : <Save size={18}/>} LƯU SẢN PHẨM
        </button>
      </div>
    </form>
  );
}
EOF

# 2. CẬP NHẬT DANH SÁCH (Xóa logic hiển thị giá giảm)
echo "📝 Đang cập nhật Danh sách sản phẩm..."
cat << 'EOF' > /var/www/lica-project/apps/admin/app/products/page.tsx
"use client";
import { useState, useEffect, useCallback, Suspense } from "react";
import axios from "axios";
import Link from "next/link";
import { useSearchParams, useRouter, usePathname } from "next/navigation";
import { Plus, Search, Edit, Trash2, Loader2, ImageOff, ChevronLeft, ChevronRight } from "lucide-react";
import { Product } from "@/types/product";

interface PaginatedResponse {
  data: Product[];
  current_page: number;
  last_page: number;
  total: number;
  per_page: number;
}

function ProductListContent() {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const [data, setData] = useState<PaginatedResponse | null>(null);
  const [loading, setLoading] = useState(true);
  
  const currentPage = Number(searchParams.get("page")) || 1;
  const searchTerm = searchParams.get("q") || "";
  const [searchInput, setSearchInput] = useState(searchTerm);

  const fetchProducts = useCallback(async () => {
    try {
      setLoading(true);
      const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product`, {
        params: { page: currentPage, q: searchTerm },
      });
      setData(res.data.data);
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  }, [currentPage, searchTerm]);

  useEffect(() => { fetchProducts(); }, [fetchProducts]);

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    const params = new URLSearchParams(searchParams.toString());
    if (searchInput) params.set("q", searchInput);
    else params.delete("q");
    params.set("page", "1");
    router.replace(`${pathname}?${params.toString()}`);
  };

  const handlePageChange = (newPage: number) => {
    if (newPage < 1 || (data && newPage > data.last_page)) return;
    const params = new URLSearchParams(searchParams.toString());
    params.set("page", newPage.toString());
    router.push(`${pathname}?${params.toString()}`);
  };

  const handleDelete = async (id: number) => {
    if (!confirm("Xóa sản phẩm này?")) return;
    try {
      await axios.delete(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/${id}`);
      fetchProducts();
    } catch (err) { alert("Lỗi xóa sản phẩm"); }
  };

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <div className="flex flex-col md:flex-row justify-between items-center mb-6 gap-4">
        <h1 className="text-2xl font-bold text-gray-800">Sản phẩm</h1>
        <Link href="/products/create" className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700 shadow font-medium">
          <Plus size={18} /> Thêm mới
        </Link>
      </div>

      <div className="bg-white p-4 rounded-lg shadow-sm border border-gray-100 mb-6">
        <form onSubmit={handleSearch} className="flex gap-3">
          <div className="relative flex-1 max-w-md">
            <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
            <input 
              type="text" placeholder="Tìm theo tên, SKU..." 
              className="w-full pl-10 pr-4 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 outline-none"
              value={searchInput} onChange={(e) => setSearchInput(e.target.value)}
            />
          </div>
          <button type="submit" className="px-4 py-2 bg-gray-800 text-white rounded-md hover:bg-gray-900">Tìm kiếm</button>
        </form>
      </div>

      <div className="bg-white rounded-lg shadow border overflow-hidden">
        <table className="w-full text-sm text-left">
          <thead className="bg-gray-50 text-gray-700 uppercase font-medium">
            <tr>
              <th className="px-4 py-3 w-16">Hình</th>
              <th className="px-4 py-3">Tên / SKU</th>
              <th className="px-4 py-3">Giá bán</th>
              <th className="px-4 py-3 text-center">Kho</th>
              <th className="px-4 py-3">Danh mục</th>
              <th className="px-4 py-3 text-right">Hành động</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
              <tr><td colSpan={6} className="p-8 text-center"><Loader2 className="animate-spin inline text-blue-600"/> Đang tải...</td></tr>
            ) : data?.data && data.data.length > 0 ? (
              data.data.map((p) => (
                <tr key={p.id} className="hover:bg-gray-50">
                  <td className="px-4 py-3">
                    {p.thumbnail ? <img src={p.thumbnail} className="w-10 h-10 object-cover rounded border" /> : <div className="w-10 h-10 bg-gray-100 rounded flex items-center justify-center"><ImageOff size={16}/></div>}
                  </td>
                  <td className="px-4 py-3">
                    <div className="font-medium text-gray-900">{p.name}</div>
                    <div className="text-xs text-gray-500 font-mono">{p.sku || "_"}</div>
                  </td>
                  <td className="px-4 py-3 font-medium text-green-600">
                    {/* ĐÃ XÓA LOGIC HIỂN THỊ GIÁ GIẢM */}
                    {new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(Number(p.price))}
                  </td>
                  <td className="px-4 py-3 text-center">
                    <span className={`px-2 py-1 rounded text-xs ${Number(p.stock_quantity) > 0 ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>{p.stock_quantity}</span>
                  </td>
                  <td className="px-4 py-3 text-gray-600">{p.category?.name || "-"}</td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex justify-end gap-2">
                      <Link href={`/products/${p.id}`} className="text-blue-600 hover:bg-blue-50 p-1 rounded"><Edit size={16}/></Link>
                      <button onClick={() => handleDelete(p.id)} className="text-red-600 hover:bg-red-50 p-1 rounded"><Trash2 size={16}/></button>
                    </div>
                  </td>
                </tr>
              ))
            ) : (
              <tr><td colSpan={6} className="p-8 text-center text-gray-500">Không tìm thấy sản phẩm.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      {data && data.last_page > 1 && (
        <div className="mt-4 flex justify-end gap-2">
          <button disabled={data.current_page === 1} onClick={() => handlePageChange(data.current_page - 1)} className="p-2 border rounded hover:bg-gray-50 disabled:opacity-50"><ChevronLeft size={16} /></button>
          <span className="px-4 py-2 text-sm text-gray-600">Trang {data.current_page} / {data.last_page}</span>
          <button disabled={data.current_page === data.last_page} onClick={() => handlePageChange(data.current_page + 1)} className="p-2 border rounded hover:bg-gray-50 disabled:opacity-50"><ChevronRight size={16} /></button>
        </div>
      )}
    </div>
  );
}

export default function ProductList() {
  return (
    <Suspense fallback={<div className="flex justify-center p-10"><Loader2 className="animate-spin text-blue-600 w-8 h-8"/></div>}>
      <ProductListContent />
    </Suspense>
  );
}
EOF

echo "🔄 Đang build lại Admin App..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Đã gỡ bỏ tính năng Giá giảm thành công!"
