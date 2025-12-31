#!/bin/bash

ADMIN_DIR="/var/www/lica-project/apps/admin"
FORM_FILE="$ADMIN_DIR/components/ProductForm.tsx"

echo ">>> ĐANG CẬP NHẬT FORM SẢN PHẨM ĐẦY ĐỦ THÔNG TIN..."

cat > "$FORM_FILE" <<TSX
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { Product, Category, Brand, Origin, Unit, SkinType } from "@/types/product";
import { 
  Save, Image as ImageIcon, Box, Tag, Plus, X, Loader2, 
  Droplets, FileText, Globe, Scale, Truck, Beaker, BookOpen 
} from "lucide-react";

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
      category_id: null, brand_id: null, origin_id: null, unit_id: null,
      skin_type_ids: [], 
      short_description: "", description: "", 
      ingredients: "", usage_instructions: "",
      images: ["", "", "", "", "", "", "", "", ""], 
      is_active: true
    }
  );

  // Fetch Master Data
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
      } catch (err) { console.error("Lỗi tải dữ liệu:", err); }
    };
    fetchData();
  }, []);

  const handleChange = (field: keyof Product, value: any) => {
    setFormData({ ...formData, [field]: value });
  };

  const toggleSkinType = (id: number) => {
    const currentIds = formData.skin_type_ids || [];
    setFormData({ 
      ...formData, 
      skin_type_ids: currentIds.includes(id) ? currentIds.filter(x => x !== id) : [...currentIds, id] 
    });
  };

  const handleFileUpload = async (index: number, file: File) => {
    if (!file) return;
    const data = new FormData();
    data.append("file", file);
    setUploadingIndex(index);
    try {
      const res = await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/cms/upload\`, data);
      const newImages = [...(formData.images || [])];
      newImages[index] = res.data.url;
      setFormData({ ...formData, images: newImages });
    } catch (error) { alert("Lỗi upload ảnh!"); } finally { setUploadingIndex(null); }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    const cleanData = {
        ...formData,
        price: Number(formData.price),
        sale_price: Number(formData.sale_price),
        stock_quantity: Number(formData.stock_quantity),
        weight: Number(formData.weight),
        length: Number(formData.length),
        width: Number(formData.width),
        height: Number(formData.height),
        images: formData.images?.filter(url => url && url.trim() !== "")
    };

    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL;
      if (isEdit && initialData) {
        await axios.put(\`\${apiUrl}/api/v1/product/\${initialData.id}\`, cleanData);
      } else {
        await axios.post(\`\${apiUrl}/api/v1/product\`, cleanData);
      }
      router.push("/products");
    } catch (error: any) {
      alert("Lỗi: " + (error.response?.data?.message || "Không thể lưu sản phẩm"));
    } finally { setLoading(false); }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6 pb-24 max-w-5xl mx-auto">
      
      {/* KHỐI 1: THÔNG TIN CƠ BẢN */}
      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <Tag size={20} className="text-blue-600" /> Thông tin cơ bản
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="md:col-span-2">
            <label className="block text-sm font-bold text-gray-700 mb-1">Tên sản phẩm *</label>
            <input type="text" required className="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-blue-500 outline-none"
              value={formData.name || ""} onChange={(e) => handleChange("name", e.target.value)} />
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">Danh mục *</label>
             <select className="w-full border border-gray-300 rounded-lg px-3 py-2 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                value={formData.category_id || ""} onChange={(e) => handleChange("category_id", e.target.value)} required >
                <option value="">-- Chọn danh mục --</option>
                {categories.map((cat: any) => (
                  <option key={cat.id} value={cat.id}>{cat.level === 0 ? "🟦 " : "⠀⠀".repeat(cat.level) + "└─ "}{cat.name}</option>
                ))}
             </select>
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">Thương hiệu</label>
             <select className="w-full border border-gray-300 rounded-lg px-3 py-2 bg-white focus:ring-2 focus:ring-blue-500 outline-none"
                value={formData.brand_id || ""} onChange={(e) => handleChange("brand_id", e.target.value)}>
                <option value="">-- Chọn thương hiệu --</option>
                {brands.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}
             </select>
          </div>
        </div>
      </div>

      {/* KHỐI 2: ĐẶC TÍNH MỸ PHẨM */}
      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <Droplets size={20} className="text-pink-500" /> Đặc tính & Quy cách
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1 flex items-center gap-1"><Globe size={14}/> Xuất xứ</label>
             <select className="w-full border border-gray-300 rounded-lg px-3 py-2 bg-white focus:ring-2 focus:ring-pink-500 outline-none"
                value={formData.origin_id || ""} onChange={(e) => handleChange("origin_id", e.target.value)}>
                <option value="">-- Chọn xuất xứ --</option>
                {origins.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
             </select>
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1 flex items-center gap-1"><Scale size={14}/> Đơn vị / Dung tích</label>
             <select className="w-full border border-gray-300 rounded-lg px-3 py-2 bg-white focus:ring-2 focus:ring-pink-500 outline-none"
                value={formData.unit_id || ""} onChange={(e) => handleChange("unit_id", e.target.value)}>
                <option value="">-- Chọn đơn vị --</option>
                {units.map(u => <option key={u.id} value={u.id}>{u.name}</option>)}
             </select>
          </div>
        </div>
        <div className="mb-4">
            <label className="block text-sm font-bold text-gray-700 mb-2 text-pink-600">Loại da phù hợp</label>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 bg-pink-50/50 p-4 rounded-xl border border-pink-100">
                {skinTypesList.map(type => (
                    <label key={type.id} className="flex items-center space-x-2 cursor-pointer hover:bg-white p-1.5 rounded-lg transition">
                        <input type="checkbox" className="w-4 h-4 text-pink-600 rounded border-gray-300 focus:ring-pink-500"
                            checked={formData.skin_type_ids?.includes(type.id) || false} onChange={() => toggleSkinType(type.id)} />
                        <span className="text-sm text-gray-700">{type.name}</span>
                    </label>
                ))}
            </div>
        </div>
      </div>

      {/* KHỐI 3: MÔ TẢ CHI TIẾT */}
      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <FileText size={20} className="text-orange-500" /> Nội dung chi tiết
        </h3>
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1 flex items-center gap-1">Mô tả ngắn (Hiển thị đầu trang)</label>
            <textarea className="w-full border border-gray-300 rounded-lg px-3 py-2 h-20 outline-none focus:ring-2 focus:ring-orange-500"
              value={formData.short_description || ""} onChange={(e) => handleChange("short_description", e.target.value)} />
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1 flex items-center gap-1">Mô tả chi tiết sản phẩm</label>
            <textarea className="w-full border border-gray-300 rounded-lg px-3 py-2 h-48 outline-none focus:ring-2 focus:ring-orange-500"
              value={formData.description || ""} onChange={(e) => handleChange("description", e.target.value)} />
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-bold text-gray-700 mb-1 flex items-center gap-1"><Beaker size={14}/> Thành phần (Ingredients)</label>
              <textarea className="w-full border border-gray-300 rounded-lg px-3 py-2 h-32 outline-none focus:ring-2 focus:ring-orange-500 font-mono text-xs"
                value={formData.ingredients || ""} onChange={(e) => handleChange("ingredients", e.target.value)} />
            </div>
            <div>
              <label className="block text-sm font-bold text-gray-700 mb-1 flex items-center gap-1"><BookOpen size={14}/> Hướng dẫn sử dụng</label>
              <textarea className="w-full border border-gray-300 rounded-lg px-3 py-2 h-32 outline-none focus:ring-2 focus:ring-orange-500"
                value={formData.usage_instructions || ""} onChange={(e) => handleChange("usage_instructions", e.target.value)} />
            </div>
          </div>
        </div>
      </div>

      {/* KHỐI 4: GIÁ & VẬN CHUYỂN */}
      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <Box size={20} className="text-green-600" /> Giá & Kho vận
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
          <div>
             <label className="block text-sm font-bold text-gray-700 mb-1 text-green-700">Giá bán (₫) *</label>
             <input type="number" className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-green-500 outline-none"
                value={formData.price || 0} onChange={(e) => handleChange("price", e.target.value)} />
          </div>
          <div>
             <label className="block text-sm font-bold text-gray-700 mb-1">Giá khuyến mãi</label>
             <input type="number" className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-green-500 outline-none"
                value={formData.sale_price || 0} onChange={(e) => handleChange("sale_price", e.target.value)} />
          </div>
          <div>
             <label className="block text-sm font-bold text-gray-700 mb-1">Số lượng kho</label>
             <input type="number" className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-green-500 outline-none"
                value={formData.stock_quantity || 0} onChange={(e) => handleChange("stock_quantity", e.target.value)} />
          </div>
          <div>
             <label className="block text-sm font-bold text-gray-700 mb-1">Mã SKU</label>
             <input type="text" className="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-green-500 outline-none uppercase font-mono"
                value={formData.sku || ""} onChange={(e) => handleChange("sku", e.target.value)} />
          </div>
        </div>

        <div className="pt-4 border-t border-gray-100">
          <label className="block text-sm font-bold text-gray-700 mb-4 flex items-center gap-2 text-blue-600"><Truck size={16}/> Thông tin vận chuyển (Dùng để tính phí ship)</label>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div>
              <label className="block text-[11px] font-bold text-gray-500 uppercase">Cân nặng (Gram)</label>
              <input type="number" className="w-full border border-gray-200 rounded-lg px-3 py-1.5 focus:ring-2 focus:ring-blue-500 outline-none" 
                value={formData.weight || 0} onChange={(e) => handleChange("weight", e.target.value)} />
            </div>
            <div>
              <label className="block text-[11px] font-bold text-gray-500 uppercase">Dài (cm)</label>
              <input type="number" className="w-full border border-gray-200 rounded-lg px-3 py-1.5 focus:ring-2 focus:ring-blue-500 outline-none" 
                value={formData.length || 0} onChange={(e) => handleChange("length", e.target.value)} />
            </div>
            <div>
              <label className="block text-[11px] font-bold text-gray-500 uppercase">Rộng (cm)</label>
              <input type="number" className="w-full border border-gray-200 rounded-lg px-3 py-1.5 focus:ring-2 focus:ring-blue-500 outline-none" 
                value={formData.width || 0} onChange={(e) => handleChange("width", e.target.value)} />
            </div>
            <div>
              <label className="block text-[11px] font-bold text-gray-500 uppercase">Cao (cm)</label>
              <input type="number" className="w-full border border-gray-200 rounded-lg px-3 py-1.5 focus:ring-2 focus:ring-blue-500 outline-none" 
                value={formData.height || 0} onChange={(e) => handleChange("height", e.target.value)} />
            </div>
          </div>
        </div>
      </div>

      {/* KHỐI 5: HÌNH ẢNH */}
      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <ImageIcon size={20} className="text-purple-600" /> Hình ảnh (Tối đa 9)
        </h3>
        <div className="flex flex-wrap gap-4">
          {[0,1,2,3,4,5,6,7,8].map((idx) => (
            <div key={idx} className="w-28 h-28 border-2 border-dashed border-gray-200 rounded-xl flex items-center justify-center relative overflow-hidden group hover:border-purple-400 transition bg-gray-50">
              {uploadingIndex === idx ? <Loader2 className="animate-spin text-purple-500" /> : 
                formData.images?.[idx] ? (
                  <><img src={formData.images[idx]} className="w-full h-full object-cover" />
                  <button type="button" onClick={() => {const ni = [...formData.images!]; ni[idx]=""; setFormData({...formData, images:ni})}} 
                    className="absolute top-1 right-1 bg-red-500 text-white p-1 rounded-lg opacity-0 group-hover:opacity-100 transition shadow-md"><X size={12}/></button></>
                ) : (
                  <label className="cursor-pointer flex flex-col items-center text-gray-400 hover:text-purple-500 h-full w-full justify-center">
                    <Plus size={20}/><span className="text-[10px] font-bold mt-1 uppercase tracking-tighter">Ảnh {idx + 1}</span>
                    <input type="file" className="hidden" accept="image/*" onChange={e => e.target.files?.[0] && handleFileUpload(idx, e.target.files[0])} />
                  </label>
                )
              }
            </div>
          ))}
        </div>
      </div>

      {/* ACTION BAR */}
      <div className="fixed bottom-0 right-0 left-64 bg-white/80 backdrop-blur-md border-t p-4 flex justify-end gap-3 z-50 shadow-[0_-10px_30px_rgba(0,0,0,0.05)]">
        <button type="button" onClick={() => router.back()} className="px-8 py-2.5 rounded-xl font-bold text-gray-500 hover:bg-gray-100 transition">HỦY BỎ</button>
        <button type="submit" disabled={loading} className="px-12 py-2.5 rounded-xl font-bold bg-blue-600 text-white hover:bg-blue-700 shadow-xl shadow-blue-200 transition flex items-center gap-2 disabled:opacity-50">
          {loading ? <Loader2 className="animate-spin" size={18}/> : <Save size={18}/>} {loading ? "ĐANG LƯU..." : "LƯU SẢN PHẨM"}
        </button>
      </div>
    </form>
  );
}
TSX

# Rebuild Admin
echo ">>> Đang build lại Frontend..."
cd "$ADMIN_DIR"
npm run build
pm2 restart lica-admin

echo "--------------------------------------------------------"
echo "✅ HOÀN TẤT NÂNG CẤP FORM SẢN PHẨM!"
echo "👉 Đã có thêm các box: Mô tả ngắn, Mô tả dài, Thành phần, HDSD."
echo "👉 Đã có thêm các box: Cân nặng, Dài, Rộng, Cao."
echo "👉 Giao diện được tối ưu hóa chuẩn E-commerce."
echo "--------------------------------------------------------"
