#!/bin/bash

ADMIN_DIR="/var/www/lica-project/apps/admin"

echo ">>> BẮT ĐẦU CẬP NHẬT FRONTEND ADMIN (THEO BACKEND MỚI)..."

# ====================================================
# 1. CẬP NHẬT TYPES (Thêm Interface cho Master Data)
# ====================================================
echo ">>> [1/3] Updating Types..."
TYPE_FILE="$ADMIN_DIR/types/product.ts"

cat > "$TYPE_FILE" <<TS
export interface Brand {
  id: number;
  name: string;
  slug: string;
  logo?: string;
}

export interface Origin {
  id: number;
  name: string;
  code?: string;
}

export interface Unit {
  id: number;
  name: string;
}

export interface SkinType {
  id: number;
  name: string;
  code?: string;
}

export interface Category {
  id: number;
  name: string;
  slug: string;
  parent_id: number | null;
  level: number;
}

export interface Product {
  id: number;
  name: string;
  slug: string;
  sku: string | null;
  price: string | number;
  sale_price: string | number | null;
  stock_quantity: number;
  thumbnail: string | null;
  images: string[] | null;
  
  // Vận chuyển
  weight: number;
  length: number;
  width: number;
  height: number;
  
  // Nội dung
  short_description: string | null;
  description: string | null;
  ingredients: string | null;
  usage_instructions: string | null;

  // Quan hệ (Master Data)
  category_id: number | null;
  brand_id: number | null;
  origin_id: number | null;
  unit_id: number | null;
  skin_type_ids: number[] | null; // Mảng ID loại da

  // Để hiển thị (Optional)
  brand?: Brand;
  origin?: Origin;
  unit?: Unit;
  category?: Category;
  
  is_active: boolean;
}
TS

# ====================================================
# 2. CẬP NHẬT PRODUCT FORM (Logic gọi API & Render)
# ====================================================
echo ">>> [2/3] Updating ProductForm Component..."
FORM_FILE="$ADMIN_DIR/components/ProductForm.tsx"

cat > "$FORM_FILE" <<TSX
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { Product, Category, Brand, Origin, Unit, SkinType } from "@/types/product";
import { Save, Image as ImageIcon, Box, Tag, Truck, Plus, X, Loader2, Droplets, FileText, Globe, Scale } from "lucide-react";

interface Props {
  initialData?: Product;
  isEdit?: boolean;
}

export default function ProductForm({ initialData, isEdit = false }: Props) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [uploadingIndex, setUploadingIndex] = useState<number | null>(null);

  // Master Data States
  const [categories, setCategories] = useState<Category[]>([]);
  const [brands, setBrands] = useState<Brand[]>([]);
  const [origins, setOrigins] = useState<Origin[]>([]);
  const [units, setUnits] = useState<Unit[]>([]);
  const [skinTypesList, setSkinTypesList] = useState<SkinType[]>([]);

  // Form State
  const [formData, setFormData] = useState<Partial<Product>>(
    initialData || {
      name: "", sku: "", price: 0, sale_price: 0, stock_quantity: 0,
      weight: 0, length: 0, width: 0, height: 0,
      category_id: null,
      brand_id: null,
      origin_id: null,
      unit_id: null,
      skin_type_ids: [], // Mảng rỗng mặc định
      short_description: "", description: "", 
      ingredients: "", usage_instructions: "",
      images: ["", "", "", "", "", "", "", "", ""], 
      is_active: true
    }
  );

  // Fetch Master Data khi load trang
  useEffect(() => {
    const fetchData = async () => {
      try {
        const apiUrl = process.env.NEXT_PUBLIC_API_URL;
        
        // Gọi song song 5 API để tiết kiệm thời gian
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

      } catch (err) { console.error("Lỗi tải dữ liệu nguồn:", err); }
    };
    fetchData();
  }, []);

  // Xử lý thay đổi input thường
  const handleChange = (field: keyof Product, value: any) => {
    setFormData({ ...formData, [field]: value });
  };

  // Xử lý checkbox Loại da (Multi-select)
  const toggleSkinType = (id: number) => {
    const currentIds = formData.skin_type_ids || [];
    if (currentIds.includes(id)) {
      setFormData({ ...formData, skin_type_ids: currentIds.filter(x => x !== id) });
    } else {
      setFormData({ ...formData, skin_type_ids: [...currentIds, id] });
    }
  };

  const handleFileUpload = async (index: number, file: File) => {
    if (!file) return;
    const data = new FormData();
    data.append("file", file);
    setUploadingIndex(index);
    try {
      const res = await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/cms/upload\`, data, {
        headers: { "Content-Type": "multipart/form-data" }
      });
      const newImages = [...(formData.images || [])];
      newImages[index] = res.data.url;
      setFormData({ ...formData, images: newImages });
    } catch (error) { alert("Lỗi upload ảnh!"); } finally { setUploadingIndex(null); }
  };

  const removeImage = (index: number) => {
    const newImages = [...(formData.images || [])];
    newImages[index] = "";
    setFormData({ ...formData, images: newImages });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    
    // Convert dữ liệu sang đúng kiểu Backend cần
    const cleanData = {
        ...formData,
        price: Number(formData.price),
        sale_price: Number(formData.sale_price),
        stock_quantity: Number(formData.stock_quantity),
        weight: Number(formData.weight),
        category_id: formData.category_id ? Number(formData.category_id) : null,
        brand_id: formData.brand_id ? Number(formData.brand_id) : null,
        origin_id: formData.origin_id ? Number(formData.origin_id) : null,
        unit_id: formData.unit_id ? Number(formData.unit_id) : null,
        images: formData.images?.filter(url => url && url.trim() !== "")
    };

    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL;
      if (isEdit && initialData) {
        await axios.put(\`\${apiUrl}/api/v1/product/\${initialData.id}\`, cleanData);
        alert("Cập nhật thành công!");
      } else {
        await axios.post(\`\${apiUrl}/api/v1/product\`, cleanData);
        alert("Tạo mới thành công!");
      }
      router.push("/products");
    } catch (error: any) {
      alert("Lỗi: " + (error.response?.data?.message || error.message));
    } finally { setLoading(false); }
  };

  // Helper render danh mục phân cấp
  const renderCategoryOptions = () => {
    const sorted = [...categories].sort((a, b) => (a.parent_id || 0) - (b.parent_id || 0) || a.id - b.id);
    return sorted.map(cat => {
        const prefix = cat.level === 0 ? "🟦 " : (cat.level === 1 ? "⠀⠀└─ " : "⠀⠀⠀⠀└─ ");
        const style = cat.level === 0 ? "font-bold text-black bg-gray-50" : "";
        return <option key={cat.id} value={cat.id} className={style}>{prefix}{cat.name}</option>;
    });
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6 pb-24">
      
      {/* 1. THÔNG TIN CƠ BẢN */}
      <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <Tag size={20} className="text-blue-600" /> Thông tin chung
        </h3>
        
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="col-span-2">
            <label className="block text-sm font-medium text-gray-700 mb-1">Tên sản phẩm <span className="text-red-500">*</span></label>
            <input type="text" required className="w-full border border-gray-300 rounded-md px-3 py-2 focus:ring-2 focus:ring-blue-500 outline-none"
              value={formData.name || ""} onChange={(e) => handleChange("name", e.target.value)} />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Danh mục <span className="text-red-500">*</span></label>
             <select className="w-full border border-gray-300 rounded-md px-3 py-2 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                value={formData.category_id || ""} onChange={(e) => handleChange("category_id", e.target.value)} required >
                <option value="">-- Chọn danh mục --</option>
                {renderCategoryOptions()}
             </select>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Thương hiệu</label>
             <select className="w-full border border-gray-300 rounded-md px-3 py-2 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                value={formData.brand_id || ""} onChange={(e) => handleChange("brand_id", e.target.value)}>
                <option value="">-- Chọn thương hiệu --</option>
                {brands.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}
             </select>
          </div>
        </div>
      </div>

      {/* 2. ĐẶC TÍNH MỸ PHẨM (UPDATE THEO API MASTER DATA) */}
      <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <Droplets size={20} className="text-pink-500" /> Đặc tính sản phẩm
        </h3>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          {/* Xuất xứ */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-1">
               <Globe size={14}/> Xuất xứ
            </label>
             <select className="w-full border border-gray-300 rounded-md px-3 py-2 bg-white focus:ring-2 focus:ring-pink-500 outline-none"
                value={formData.origin_id || ""} onChange={(e) => handleChange("origin_id", e.target.value)}>
                <option value="">-- Chọn xuất xứ --</option>
                {origins.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
             </select>
          </div>

          {/* Đơn vị tính */}
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1 flex items-center gap-1">
               <Scale size={14}/> Đơn vị / Dung tích
            </label>
             <select className="w-full border border-gray-300 rounded-md px-3 py-2 bg-white focus:ring-2 focus:ring-pink-500 outline-none"
                value={formData.unit_id || ""} onChange={(e) => handleChange("unit_id", e.target.value)}>
                <option value="">-- Chọn đơn vị --</option>
                {units.map(u => <option key={u.id} value={u.id}>{u.name}</option>)}
             </select>
          </div>
        </div>

        {/* Loại da (Checkbox Group) */}
        <div className="mb-6">
            <label className="block text-sm font-medium text-gray-700 mb-2">Loại da phù hợp</label>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 bg-gray-50 p-4 rounded-md border border-gray-200">
                {skinTypesList.length > 0 ? skinTypesList.map(type => (
                    <label key={type.id} className="flex items-center space-x-2 cursor-pointer hover:bg-gray-100 p-1 rounded">
                        <input 
                            type="checkbox" 
                            className="w-4 h-4 text-pink-600 rounded border-gray-300 focus:ring-pink-500"
                            checked={formData.skin_type_ids?.includes(type.id) || false}
                            onChange={() => toggleSkinType(type.id)}
                        />
                        <span className="text-sm text-gray-700">{type.name}</span>
                    </label>
                )) : <span className="text-xs text-gray-400 italic">Chưa có dữ liệu loại da trong hệ thống</span>}
            </div>
        </div>

        {/* Thành phần & HDSD */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
             <label className="block text-sm font-medium text-gray-700 mb-1">Thành phần (Ingredients)</label>
             <textarea className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm h-32 outline-none focus:ring-2 focus:ring-pink-500 font-mono"
                placeholder="Aqua, Glycerin, Niacinamide..."
                value={formData.ingredients || ""} onChange={(e) => handleChange("ingredients", e.target.value)} />
          </div>
          <div>
             <label className="block text-sm font-medium text-gray-700 mb-1">Hướng dẫn sử dụng</label>
             <textarea className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm h-32 outline-none focus:ring-2 focus:ring-pink-500"
                placeholder="Bước 1: Làm sạch da..."
                value={formData.usage_instructions || ""} onChange={(e) => handleChange("usage_instructions", e.target.value)} />
          </div>
        </div>
      </div>

      {/* 3. GIÁ & KHO */}
      <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <Box size={20} className="text-green-600" /> Giá & Tồn kho
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div>
             <label className="block text-sm font-medium text-gray-700 mb-1">Giá bán (₫) <span className="text-red-500">*</span></label>
             <input type="number" className="w-full border border-gray-300 rounded-md px-3 py-2 outline-none focus:ring-2 focus:ring-green-500"
                value={formData.price || 0} onChange={(e) => handleChange("price", e.target.value)} />
          </div>
          <div>
             <label className="block text-sm font-medium text-gray-700 mb-1">Giá khuyến mãi</label>
             <input type="number" className="w-full border border-gray-300 rounded-md px-3 py-2 outline-none focus:ring-2 focus:ring-green-500"
                value={formData.sale_price || 0} onChange={(e) => handleChange("sale_price", e.target.value)} />
          </div>
          <div>
             <label className="block text-sm font-medium text-gray-700 mb-1">Số lượng kho</label>
             <input type="number" className="w-full border border-gray-300 rounded-md px-3 py-2 outline-none focus:ring-2 focus:ring-green-500"
                value={formData.stock_quantity || 0} onChange={(e) => handleChange("stock_quantity", e.target.value)} />
          </div>
        </div>
        <div className="mt-4 grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Mã SKU</label>
                <input type="text" className="w-full border border-gray-300 rounded-md px-3 py-2 outline-none focus:ring-2 focus:ring-green-500 uppercase"
                    value={formData.sku || ""} onChange={(e) => handleChange("sku", e.target.value)} />
            </div>
            <div className="flex items-center pt-6">
                <label className="flex items-center gap-2 cursor-pointer">
                    <input type="checkbox" className="w-5 h-5 text-green-600 rounded"
                        checked={formData.is_active} onChange={(e) => handleChange("is_active", e.target.checked)} />
                    <span className="text-sm font-medium text-gray-700">Đang kinh doanh (Active)</span>
                </label>
            </div>
        </div>
      </div>

      {/* 4. MÔ TẢ & ẢNH */}
      <div className="bg-white p-6 rounded-lg shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <FileText size={20} className="text-purple-600" /> Nội dung & Hình ảnh
        </h3>
        
        <div className="mb-6">
             <label className="block text-sm font-medium text-gray-700 mb-1">Mô tả chi tiết</label>
             <textarea className="w-full border border-gray-300 rounded-md px-3 py-2 text-sm h-48 outline-none focus:ring-2 focus:ring-purple-500"
                placeholder="Bài viết chuẩn SEO..."
                value={formData.description || ""} onChange={(e) => handleChange("description", e.target.value)} />
        </div>

        <div>
            <label className="block text-sm font-medium text-gray-700 mb-3 flex items-center gap-2">
                <ImageIcon size={16}/> Bộ sưu tập ảnh (Tối đa 9 ảnh)
            </label>
            <div className="flex flex-wrap gap-4">
                {[0,1,2,3,4,5,6,7,8].map((index) => (
                    <div key={index} className="w-24 h-24 border-2 border-dashed border-gray-300 rounded-lg hover:border-purple-500 relative group bg-gray-50 flex items-center justify-center overflow-hidden transition-all">
                        {uploadingIndex === index ? (
                            <div className="animate-spin text-purple-600"><Loader2 size={24}/></div>
                        ) : formData.images?.[index] ? (
                            <>
                                <img src={formData.images[index]} className="w-full h-full object-cover" />
                                <button type="button" onClick={() => removeImage(index)}
                                    className="absolute top-0 right-0 bg-red-500 text-white p-1 rounded-bl opacity-0 group-hover:opacity-100 transition shadow-sm">
                                    <X size={12} />
                                </button>
                            </>
                        ) : (
                            <label className="cursor-pointer w-full h-full flex flex-col items-center justify-center text-gray-400 hover:text-purple-600 hover:bg-purple-50 transition">
                                <Plus size={24} />
                                <input type="file" accept="image/*" className="hidden"
                                    onChange={(e) => { if(e.target.files?.[0]) handleFileUpload(index, e.target.files[0]); }} />
                            </label>
                        )}
                    </div>
                ))}
            </div>
        </div>
      </div>

      {/* FOOTER ACTION */}
      <div className="fixed bottom-0 right-0 left-0 md:left-64 bg-white border-t p-4 shadow-lg flex justify-end gap-3 z-50">
         <button type="button" onClick={() => router.back()} className="px-6 py-2.5 rounded-md text-sm font-medium border border-gray-300 hover:bg-gray-50 text-gray-700 transition">Hủy bỏ</button>
         <button type="submit" disabled={loading}
            className="px-6 py-2.5 rounded-md text-sm font-medium bg-blue-600 text-white hover:bg-blue-700 shadow-md flex items-center gap-2 transition disabled:opacity-70">
            {loading ? <Loader2 className="animate-spin" size={18} /> : <Save size={18} />}
            {loading ? "Đang lưu..." : "Lưu sản phẩm"}
         </button>
      </div>

    </form>
  );
}
TSX

# ====================================================
# 3. BUILD & DEPLOY
# ====================================================
echo ">>> [3/3] Rebuilding Admin Frontend..."
cd "$ADMIN_DIR"

# Cài đặt lại node_modules nếu cần (để đảm bảo không lỗi type)
# npm install

# Build
npm run build

# Restart PM2
pm2 restart lica-admin 2>/dev/null

echo "--------------------------------------------------------"
echo "✅ ĐÃ CẬP NHẬT GIAO DIỆN ADMIN THÀNH CÔNG!"
echo "👉 Trang thêm sản phẩm đã có Select Box cho Thương hiệu, Xuất xứ..."
echo "👉 Truy cập thử: https://admin.lica.vn/products/create"
echo "--------------------------------------------------------"
