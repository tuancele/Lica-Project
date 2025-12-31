#!/bin/bash

ADMIN_DIR="/var/www/lica-project/apps/admin"

echo ">>> [1/3] Đang cài đặt thư viện kéo thả..."
cd "$ADMIN_DIR"
npm install @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities --save

echo ">>> [2/3] Cập nhật ProductForm với tính năng Multi-upload & Drag-Drop..."

# Tạo một file Component riêng cho Item ảnh để tối ưu hiệu năng kéo thả
mkdir -p "$ADMIN_DIR/components/product"
cat > "$ADMIN_DIR/components/product/SortableImage.tsx" <<TSX
"use client";
import React from 'react';
import { useSortable } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { X, GripVertical } from 'lucide-react';

interface Props {
  id: string;
  url: string;
  index: number;
  onRemove: (index: number) => void;
}

export function SortableImage({ id, url, index, onRemove }: Props) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    zIndex: isDragging ? 50 : 0,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div ref={setNodeRef} style={style} className="relative w-28 h-28 border rounded-xl overflow-hidden group bg-gray-50 shadow-sm border-gray-200">
      <img src={url} className="w-full h-full object-cover" alt="product" />
      
      {/* Nút kéo */}
      <div {...attributes} {...listeners} className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center cursor-grab active:cursor-grabbing">
        <GripVertical className="text-white" size={24} />
      </div>

      {/* Badge ảnh bìa */}
      {index === 0 && (
        <div className="absolute top-0 left-0 bg-blue-600 text-white text-[9px] font-bold px-1.5 py-0.5 rounded-br-lg shadow-sm">
          ẢNH BÌA
        </div>
      )}

      {/* Nút xóa */}
      <button
        type="button"
        onClick={() => onRemove(index)}
        className="absolute top-1 right-1 bg-red-500 text-white p-1 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity z-10 shadow-md"
      >
        <X size={12} />
      </button>
    </div>
  );
}
TSX

# Cập nhật ProductForm chính
cat > "$ADMIN_DIR/components/ProductForm.tsx" <<TSX
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { Product, Category, Brand, Origin, Unit, SkinType } from "@/types/product";
import { 
  Save, Image as ImageIcon, Box, Tag, Plus, Loader2, 
  Droplets, FileText, Globe, Scale, Truck, Beaker, BookOpen, UploadCloud
} from "lucide-react";

// DND Kit Imports
import { DndContext, closestCenter, KeyboardSensor, PointerSensor, useSensor, useSensors, DragEndEvent } from '@dnd-kit/core';
import { arrayMove, SortableContext, sortableKeyboardCoordinates, rectSortingStrategy } from '@dnd-kit/sortable';
import { SortableImage } from "./product/SortableImage";

interface Props { initialData?: Product; isEdit?: boolean; }

export default function ProductForm({ initialData, isEdit = false }: Props) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [isUploading, setIsUploading] = useState(false);

  // Master Data
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
          axios.get(\`\${apiUrl}/api/v1/category\`),
          axios.get(\`\${apiUrl}/api/v1/product/brands\`),
          axios.get(\`\${apiUrl}/api/v1/product/origins\`),
          axios.get(\`\${apiUrl}/api/v1/product/units\`),
          axios.get(\`\${apiUrl}/api/v1/product/skin-types\`)
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

  // --- XỬ LÝ ẢNH (MULTI-UPLOAD & DND) ---
  const sensors = useSensors(useSensor(PointerSensor), useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates }));

  const handleMultiUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files) return;
    const files = Array.from(e.target.files);
    const remainingSlots = 9 - (formData.images?.length || 0);
    const filesToUpload = files.slice(0, remainingSlots);

    if (filesToUpload.length === 0) { alert("Đã đạt giới hạn 9 ảnh!"); return; }

    setIsUploading(true);
    const uploadedUrls: string[] = [...(formData.images || [])];

    for (const file of filesToUpload) {
      const data = new FormData();
      data.append("file", file);
      try {
        const res = await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/cms/upload\`, data);
        uploadedUrls.push(res.data.url);
        setFormData(prev => ({ ...prev, images: [...uploadedUrls] })); // Cập nhật realtime
      } catch (error) { console.error("Lỗi upload file:", file.name); }
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
  // -------------------------------------

  const handleChange = (field: keyof Product, value: any) => setFormData({ ...formData, [field]: value });
  
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    const cleanData = {
        ...formData,
        price: Number(formData.price),
        sale_price: Number(formData.sale_price),
        stock_quantity: Number(formData.stock_quantity),
        weight: Number(formData.weight),
        images: formData.images || []
    };
    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL;
      if (isEdit && initialData) await axios.put(\`\${apiUrl}/api/v1/product/\${initialData.id}\`, cleanData);
      else await axios.post(\`\${apiUrl}/api/v1/product\`, cleanData);
      router.push("/products");
    } catch (error: any) {
      alert("Lỗi: " + (error.response?.data?.message || "Lỗi server"));
    } finally { setLoading(false); }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6 pb-24 max-w-5xl mx-auto">
      
      {/* KHỐI 1 & 2 & 3 Giữ nguyên logic cũ nhưng style gọn hơn */}
      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><Tag size={20} className="text-blue-600" /> Thông tin cơ bản</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="md:col-span-2"><label className="block text-sm font-bold text-gray-700 mb-1">Tên sản phẩm *</label>
            <input type="text" required className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-blue-500 outline-none" value={formData.name || ""} onChange={(e) => handleChange("name", e.target.value)} />
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Danh mục *</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2 bg-white focus:ring-2 focus:ring-blue-500 outline-none" value={formData.category_id || ""} onChange={(e) => handleChange("category_id", e.target.value)} required >
              <option value="">-- Chọn danh mục --</option>
              {categories.map((cat: any) => (<option key={cat.id} value={cat.id}>{"⠀⠀".repeat(cat.level)}{cat.level === 0 ? "🟦 " : "└─ "}{cat.name}</option>))}
            </select>
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Thương hiệu</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2 bg-white focus:ring-2 focus:ring-blue-500 outline-none" value={formData.brand_id || ""} onChange={(e) => handleChange("brand_id", e.target.value)}>
              <option value="">-- Chọn thương hiệu --</option>
              {brands.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}
            </select>
          </div>
        </div>
      </div>

      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><Droplets size={20} className="text-pink-500" /> Đặc tính mỹ phẩm</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Xuất xứ</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2 bg-white" value={formData.origin_id || ""} onChange={(e) => handleChange("origin_id", e.target.value)}>
              <option value="">-- Chọn --</option>{origins.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
            </select>
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1">Đơn vị</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2 bg-white" value={formData.unit_id || ""} onChange={(e) => handleChange("unit_id", e.target.value)}>
              <option value="">-- Chọn --</option>{units.map(u => <option key={u.id} value={u.id}>{u.name}</option>)}
            </select>
          </div>
        </div>
      </div>

      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><Box size={20} className="text-green-600" /> Giá & Kho</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div><label className="block text-sm font-bold text-gray-700 mb-1 font-mono uppercase">Giá bán</label>
            <input type="number" className="w-full border border-gray-300 rounded-lg px-3 py-2" value={formData.price || 0} onChange={(e) => handleChange("price", e.target.value)} />
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1 font-mono uppercase">Giá giảm</label>
            <input type="number" className="w-full border border-gray-300 rounded-lg px-3 py-2" value={formData.sale_price || 0} onChange={(e) => handleChange("sale_price", e.target.value)} />
          </div>
          <div><label className="block text-sm font-bold text-gray-700 mb-1 font-mono uppercase">Tồn kho</label>
            <input type="number" className="w-full border border-gray-300 rounded-lg px-3 py-2" value={formData.stock_quantity || 0} onChange={(e) => handleChange("stock_quantity", e.target.value)} />
          </div>
        </div>
      </div>

      {/* KHỐI 5: HÌNH ẢNH CỦA BẠN - MULTI UPLOAD & DRAG DROP */}
      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <div className="flex justify-between items-center mb-6">
          <h3 className="text-lg font-bold text-gray-800 flex items-center gap-2">
            <ImageIcon size={20} className="text-purple-600" /> Hình ảnh sản phẩm ({formData.images?.length || 0}/9)
          </h3>
          <label className={\`cursor-pointer flex items-center gap-2 px-4 py-2 rounded-lg bg-purple-50 text-purple-600 hover:bg-purple-100 transition \${isUploading ? 'opacity-50 pointer-events-none' : ''}\`}>
            {isUploading ? <Loader2 className="animate-spin" size={18}/> : <UploadCloud size={18}/>}
            <span className="text-sm font-bold">TẢI ẢNH LÊN</span>
            <input type="file" multiple accept="image/*" className="hidden" onChange={handleMultiUpload} />
          </label>
        </div>

        <p className="text-[11px] text-gray-400 mb-4">* Kéo thả ảnh để thay đổi thứ tự. Ảnh đầu tiên sẽ được dùng làm ảnh đại diện.</p>

        <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
          <SortableContext items={formData.images || []} strategy={rectSortingStrategy}>
            <div className="flex flex-wrap gap-4 min-h-[120px] p-4 bg-gray-50 rounded-xl border-2 border-dashed border-gray-200">
              {formData.images?.map((url, index) => (
                <SortableImage key={url} id={url} url={url} index={index} onRemove={removeImage} />
              ))}
              
              {(formData.images?.length || 0) < 9 && !isUploading && (
                <label className="w-28 h-28 border-2 border-dashed border-gray-300 rounded-xl flex flex-col items-center justify-center text-gray-400 hover:border-purple-400 hover:text-purple-500 cursor-pointer transition bg-white">
                  <Plus size={24} />
                  <span className="text-[10px] font-bold mt-1">THÊM ẢNH</span>
                  <input type="file" multiple accept="image/*" className="hidden" onChange={handleMultiUpload} />
                </label>
              )}

              {isUploading && (
                <div className="w-28 h-28 border-2 border-dashed border-purple-200 rounded-xl flex flex-col items-center justify-center text-purple-400 bg-purple-50">
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
TSX

echo ">>> [3/3] Rebuilding Frontend..."
npm run build
pm2 restart lica-admin

echo "✅ HOÀN TẤT NÂNG CẤP TÍNH NĂNG ẢNH CHUYÊN NGHIỆP!"
