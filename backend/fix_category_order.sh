#!/bin/bash

BACKEND_DIR="/var/www/lica-project/backend"
ADMIN_DIR="/var/www/lica-project/apps/admin"

echo ">>> 1/2: ĐANG NÂNG CẤP BACKEND (LOGIC SẮP XẾP CÂY DANH MỤC)..."

# Cập nhật CategoryController để trả về dữ liệu đã được sắp xếp phân cấp
cat > "$BACKEND_DIR/Modules/Product/app/Http/Controllers/CategoryController.php" <<PHP
<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Category;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    public function index(Request \$request)
    {
        // Lấy tất cả danh mục
        \$allCategories = Category::with('parent')->get();
        
        // Logic sắp xếp theo dạng cây (Recursive)
        \$sorted = [];
        \$this->buildTree(\$allCategories, null, 0, \$sorted);

        return response()->json(['status' => 200, 'data' => \$sorted]);
    }

    // Hàm đệ quy để sắp xếp: Cha -> các con của cha đó -> Cha tiếp theo
    private function buildTree(\$items, \$parentId, \$level, &\$result) {
        foreach (\$items as \$item) {
            if (\$item->parent_id == \$parentId) {
                \$item->level = \$level;
                \$result[] = \$item;
                \$this->buildTree(\$items, \$item->id, \$level + 1, \$result);
            }
        }
    }

    public function store(Request \$request) {
        \$request->validate(['name' => 'required|string|max:255']);
        \$slug = Str::slug(\$request->name);
        if (Category::where('slug', \$slug)->exists()) \$slug .= '-' . time();
        \$category = Category::create(['name' => \$request->name, 'slug' => \$slug, 'parent_id' => \$request->parent_id, 'description' => \$request->description, 'image' => \$request->image]);
        return response()->json(['status' => 201, 'data' => \$category]);
    }

    public function update(Request \$request, \$id) {
        \$category = Category::find(\$id);
        if (!\$category) return response()->json(['message' => 'Not found'], 404);
        \$data = \$request->all();
        if (\$request->has('name') && \$request->name !== \$category->name) \$data['slug'] = Str::slug(\$request->name) . '-' . rand(10, 99);
        \$category->update(\$data);
        return response()->json(['status' => 200, 'data' => \$category]);
    }

    public function destroy(\$id) {
        Category::where('parent_id', \$id)->update(['parent_id' => null]);
        Category::destroy(\$id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
PHP

echo ">>> 2/2: ĐANG NÂNG CẤP FRONTEND (HIỂN THỊ SELECT BOX PHÂN CẤP)..."

# Cập nhật hàm renderCategoryOptions trong ProductForm.tsx
# Tôi sẽ dùng sed để thay thế hàm render cũ bằng hàm render mới chuẩn xác hơn
cat > "$ADMIN_DIR/components/ProductForm.tsx" <<TSX
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
      ingredients: "", usage_instructions: "",
      images: ["", "", "", "", "", "", "", "", ""], is_active: true
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
      } catch (err) { console.error("Error fetching master data", err); }
    };
    fetchData();
  }, []);

  const handleChange = (field: keyof Product, value: any) => { setFormData({ ...formData, [field]: value }); };
  const toggleSkinType = (id: number) => {
    const currentIds = formData.skin_type_ids || [];
    setFormData({ ...formData, skin_type_ids: currentIds.includes(id) ? currentIds.filter(x => x !== id) : [...currentIds, id] });
  };

  const handleFileUpload = async (index: number, file: File) => {
    const data = new FormData(); data.append("file", file); setUploadingIndex(index);
    try {
      const res = await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/cms/upload\`, data);
      const newImages = [...(formData.images || [])]; newImages[index] = res.data.url;
      setFormData({ ...formData, images: newImages });
    } catch (error) { alert("Upload lỗi!"); } finally { setUploadingIndex(null); }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault(); setLoading(true);
    const cleanData = { ...formData, price: Number(formData.price), sale_price: Number(formData.sale_price), images: formData.images?.filter(url => url && url.trim() !== "") };
    try {
      if (isEdit && initialData) await axios.put(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/\${initialData.id}\`, cleanData);
      else await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/product\`, cleanData);
      router.push("/products");
    } catch (error: any) { alert("Lỗi lưu sản phẩm"); } finally { setLoading(false); }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6 pb-24 max-w-5xl mx-auto">
      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><Tag size={20} className="text-blue-600" /> Thông tin cơ bản</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="md:col-span-2">
            <label className="block text-sm font-bold text-gray-700 mb-1">Tên sản phẩm *</label>
            <input type="text" required className="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-blue-500 outline-none transition" value={formData.name || ""} onChange={(e) => handleChange("name", e.target.value)} />
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">Danh mục sản phẩm *</label>
            <select required className="w-full border border-gray-300 rounded-lg px-3 py-2.5 bg-white focus:ring-2 focus:ring-blue-500 outline-none" value={formData.category_id || ""} onChange={(e) => handleChange("category_id", e.target.value)}>
              <option value="">-- Chọn danh mục --</option>
              {categories.map((cat: any) => (
                <option key={cat.id} value={cat.id} style={{ paddingLeft: \`\${cat.level * 20}px\` }}>
                  {cat.level === 0 ? "🟦 " : "⠀⠀".repeat(cat.level) + "└─ "}{cat.name}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">Thương hiệu</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2.5 bg-white focus:ring-2 focus:ring-blue-500 outline-none" value={formData.brand_id || ""} onChange={(e) => handleChange("brand_id", e.target.value)}>
              <option value="">-- Chọn thương hiệu --</option>
              {brands.map(b => <option key={b.id} value={b.id}>{b.name}</option>)}
            </select>
          </div>
        </div>
      </div>

      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><Droplets size={20} className="text-pink-500" /> Đặc tính & Quy cách</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-6">
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">Xuất xứ</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2.5 bg-white focus:ring-2 focus:ring-pink-500 outline-none" value={formData.origin_id || ""} onChange={(e) => handleChange("origin_id", e.target.value)}>
              <option value="">-- Chọn quốc gia --</option>
              {origins.map(o => <option key={o.id} value={o.id}>{o.name}</option>)}
            </select>
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">Dung tích / Đơn vị</label>
            <select className="w-full border border-gray-300 rounded-lg px-3 py-2.5 bg-white focus:ring-2 focus:ring-pink-500 outline-none" value={formData.unit_id || ""} onChange={(e) => handleChange("unit_id", e.target.value)}>
              <option value="">-- Chọn đơn vị --</option>
              {units.map(u => <option key={u.id} value={u.id}>{u.name}</option>)}
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
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><Box size={20} className="text-green-600" /> Giá & Kho</h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">Giá bán (₫)</label>
            <input type="number" className="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-green-500 outline-none" value={formData.price || 0} onChange={(e) => handleChange("price", e.target.value)} />
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">Giá khuyến mãi</label>
            <input type="number" className="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-green-500 outline-none" value={formData.sale_price || 0} onChange={(e) => handleChange("sale_price", e.target.value)} />
          </div>
          <div>
            <label className="block text-sm font-bold text-gray-700 mb-1">Số lượng tồn</label>
            <input type="number" className="w-full border border-gray-300 rounded-lg px-4 py-2.5 focus:ring-2 focus:ring-green-500 outline-none" value={formData.stock_quantity || 0} onChange={(e) => handleChange("stock_quantity", e.target.value)} />
          </div>
        </div>
      </div>

      <div className="bg-white p-6 rounded-xl shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2"><ImageIcon size={20} className="text-purple-600" /> Hình ảnh (Tối đa 9)</h3>
        <div className="flex flex-wrap gap-4">
          {[0,1,2,3,4,5,6,7,8].map((idx) => (
            <div key={idx} className="w-28 h-28 border-2 border-dashed border-gray-200 rounded-xl flex items-center justify-center relative overflow-hidden group hover:border-purple-400 transition">
              {uploadingIndex === idx ? <Loader2 className="animate-spin text-purple-500" /> : 
                formData.images?.[idx] ? (
                  <><img src={formData.images[idx]} className="w-full h-full object-cover" />
                  <button type="button" onClick={() => {const ni = [...formData.images!]; ni[idx]=""; setFormData({...formData, images:ni})}} className="absolute top-1 right-1 bg-red-500 text-white p-1 rounded-lg opacity-0 group-hover:opacity-100 transition"><X size={12}/></button></>
                ) : (
                  <label className="cursor-pointer flex flex-col items-center text-gray-400 hover:text-purple-500">
                    <Plus size={20}/><span className="text-[10px] font-bold mt-1">THÊM ẢNH</span>
                    <input type="file" className="hidden" onChange={e => e.target.files?.[0] && handleFileUpload(idx, e.target.files[0])} />
                  </label>
                )
              }
            </div>
          ))}
        </div>
      </div>

      <div className="fixed bottom-0 right-0 left-64 bg-white/80 backdrop-blur-md border-t p-4 flex justify-end gap-3 z-50 shadow-[0_-4px_20px_rgba(0,0,0,0.05)]">
        <button type="button" onClick={() => router.back()} className="px-8 py-2.5 rounded-xl font-bold text-gray-500 hover:bg-gray-100 transition">HỦY BỎ</button>
        <button type="submit" disabled={loading} className="px-10 py-2.5 rounded-xl font-bold bg-blue-600 text-white hover:bg-blue-700 shadow-lg shadow-blue-200 transition flex items-center gap-2">
          {loading ? <Loader2 className="animate-spin" size={18}/> : <Save size={18}/>} {loading ? "ĐANG LƯU..." : "LƯU SẢN PHẨM"}
        </button>
      </div>
    </form>
  );
}
TSX

# Rebuild
cd "$ADMIN_DIR"
npm run build
pm2 restart lica-admin

echo ">>> HOÀN TẤT! DANH MỤC ĐÃ ĐƯỢC SẮP XẾP CHUẨN CÂY PHÂN CẤP."
