"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import { Product, Category } from "@/types/product";
// Thêm icon Droplets (Giọt nước) cho phần mỹ phẩm
import { Save, Image as ImageIcon, Box, Tag, Truck, Plus, X, Loader2, Droplets, FileText } from "lucide-react";

interface Props {
  initialData?: Product;
  isEdit?: boolean;
}

export default function ProductForm({ initialData, isEdit = false }: Props) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [categories, setCategories] = useState<Category[]>([]);
  const [uploadingIndex, setUploadingIndex] = useState<number | null>(null);
  
  // Khởi tạo form với đầy đủ 4 trường mới
  const [formData, setFormData] = useState<Partial<Product>>(
    initialData || {
      name: "", sku: "", price: "0", sale_price: "0", stock_quantity: 0,
      weight: 0, length: 0, width: 0, height: 0,
      brand: "", category_id: null,
      short_description: "", description: "", 
      // 4 trường mới (Mặc định là rỗng để tránh lỗi null)
      ingredients: "", usage_instructions: "", skin_type: "", capacity: "",
      images: ["", "", "", "", "", "", "", "", ""], 
      is_active: true
    }
  );

  // Danh sách loại da chuẩn
  const skinTypes = [
    "Mọi loại da",
    "Da dầu / Hỗn hợp thiên dầu",
    "Da khô / Hỗn hợp thiên khô",
    "Da nhạy cảm",
    "Da mụn",
    "Da thường",
    "Da lão hóa"
  ];

  useEffect(() => {
    const fetchCategories = async () => {
      try {
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/category`);
        setCategories(res.data.data);
      } catch (err) { console.error(err); }
    };
    fetchCategories();
  }, []);

  const renderCategoryOptions = () => {
    const sorted = [...categories].sort((a, b) => (a.parent_id || 0) - (b.parent_id || 0) || a.id - b.id);
    return sorted.map(cat => {
        const prefix = cat.level === 0 ? "🟦 " : (cat.level === 1 ? "⠀⠀└─ " : "⠀⠀⠀⠀└─ ");
        const style = cat.level === 0 ? "font-bold text-black bg-gray-100" : "";
        return <option key={cat.id} value={cat.id} className={style}>{prefix}{cat.name}</option>;
    });
  };

  const handleChange = (field: keyof Product, value: any) => {
    setFormData({ ...formData, [field]: value });
  };

  const handleFileUpload = async (index: number, file: File) => {
    if (!file) return;
    const data = new FormData();
    data.append("file", file);
    setUploadingIndex(index);
    try {
      const res = await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/cms/upload`, data, {
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
    const cleanData = {
        ...formData,
        category_id: formData.category_id ? Number(formData.category_id) : null,
        images: formData.images?.filter(url => url && url.trim() !== "")
    };

    try {
      if (isEdit && initialData) {
        await axios.put(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/${initialData.id}`, cleanData);
        alert("Cập nhật thành công!");
      } else {
        await axios.post(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product`, cleanData);
        alert("Tạo mới thành công!");
      }
      router.push("/products");
    } catch (error: any) {
      alert("Lỗi: " + (error.response?.data?.message || error.message));
    } finally { setLoading(false); }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-6 pb-20">
      
      {/* 1. THÔNG TIN CƠ BẢN */}
      <div className="bg-white p-6 rounded-md shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <Tag size={20} className="text-yellow-600" /> Thông tin cơ bản
        </h3>
        
        <div className="grid grid-cols-12 gap-6 items-center mb-6">
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium">Tên sản phẩm <span className="text-red-500">*</span></div>
          <div className="col-span-10">
            <input type="text" required className="w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none focus:border-yellow-500"
              value={formData.name || ""} onChange={(e) => handleChange("name", e.target.value)} />
          </div>
        </div>

        <div className="grid grid-cols-12 gap-6 items-center mb-6">
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium">Danh mục <span className="text-red-500">*</span></div>
          <div className="col-span-10">
             <select className="w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none bg-white h-10 focus:border-yellow-500"
                value={formData.category_id || ""} onChange={(e) => handleChange("category_id", e.target.value)} required >
                <option value="">-- Chọn danh mục --</option>
                {renderCategoryOptions()}
             </select>
          </div>
        </div>
        
        <div className="grid grid-cols-12 gap-6 items-center mb-6">
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium">Thương hiệu</div>
          <div className="col-span-10">
             <input type="text" className="w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none focus:border-yellow-500"
                placeholder="VD: La Roche-Posay"
                value={formData.brand || ""} onChange={(e) => handleChange("brand", e.target.value)} />
          </div>
        </div>
      </div>

      {/* --- MỚI: KHỐI ĐẶC TÍNH MỸ PHẨM --- */}
      <div className="bg-white p-6 rounded-md shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <Droplets size={20} className="text-yellow-600" /> Đặc tính mỹ phẩm
        </h3>

        <div className="grid grid-cols-12 gap-6 items-center mb-6">
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium">Loại da phù hợp</div>
          <div className="col-span-4">
             <select className="w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none bg-white h-10 focus:border-yellow-500"
                value={formData.skin_type || ""} onChange={(e) => handleChange("skin_type", e.target.value)}>
                <option value="">-- Chọn loại da --</option>
                {skinTypes.map(type => <option key={type} value={type}>{type}</option>)}
             </select>
          </div>

          <div className="col-span-2 text-right text-sm text-gray-600 font-medium">Dung tích / Trọng lượng</div>
          <div className="col-span-4">
             <input type="text" className="w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none focus:border-yellow-500"
                placeholder="VD: 50ml, 150g, 1 vỉ..."
                value={formData.capacity || ""} onChange={(e) => handleChange("capacity", e.target.value)} />
          </div>
        </div>

        <div className="grid grid-cols-12 gap-6 items-start mb-6">
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium pt-2">Thành phần (Ingredients)</div>
          <div className="col-span-10">
             <textarea className="w-full border border-gray-300 rounded px-3 py-2 text-sm h-24 outline-none focus:border-yellow-500 font-mono"
                placeholder="Aqua, Glycerin, Niacinamide..."
                value={formData.ingredients || ""} onChange={(e) => handleChange("ingredients", e.target.value)} />
          </div>
        </div>

        <div className="grid grid-cols-12 gap-6 items-start mb-6">
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium pt-2">Hướng dẫn sử dụng</div>
          <div className="col-span-10">
             <textarea className="w-full border border-gray-300 rounded px-3 py-2 text-sm h-24 outline-none focus:border-yellow-500"
                placeholder="Bước 1: Làm sạch da. Bước 2: Thoa đều..."
                value={formData.usage_instructions || ""} onChange={(e) => handleChange("usage_instructions", e.target.value)} />
          </div>
        </div>
      </div>

      {/* --- CÁC KHỐI CŨ (GIỮ NGUYÊN) --- */}
      
      {/* THÔNG TIN BÁN HÀNG */}
      <div className="bg-white p-6 rounded-md shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <Box size={20} className="text-yellow-600" /> Thông tin bán hàng
        </h3>
        <div className="grid grid-cols-12 gap-6 items-center mb-6">
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium">Giá bán (₫) <span className="text-red-500">*</span></div>
          <div className="col-span-4">
             <input type="number" className="w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none"
                value={formData.price || 0} onChange={(e) => handleChange("price", e.target.value)} />
          </div>
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium">Giá khuyến mãi</div>
          <div className="col-span-4">
             <input type="number" className="w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none"
                value={formData.sale_price || 0} onChange={(e) => handleChange("sale_price", e.target.value)} />
          </div>
        </div>
        <div className="grid grid-cols-12 gap-6 items-center mb-6">
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium">Kho hàng</div>
          <div className="col-span-4">
             <input type="number" className="w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none"
                value={formData.stock_quantity || 0} onChange={(e) => handleChange("stock_quantity", parseInt(e.target.value))} />
          </div>
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium">SKU</div>
          <div className="col-span-4">
             <input type="text" className="w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none"
                value={formData.sku || ""} onChange={(e) => handleChange("sku", e.target.value)} />
          </div>
        </div>
      </div>

      {/* MÔ TẢ CHI TIẾT */}
      <div className="bg-white p-6 rounded-md shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <FileText size={20} className="text-yellow-600" /> Mô tả chi tiết
        </h3>
        <div className="grid grid-cols-12 gap-6 items-start">
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium pt-2">Nội dung bài viết</div>
          <div className="col-span-10">
             <textarea className="w-full border border-gray-300 rounded px-3 py-2 text-sm h-48 outline-none focus:border-yellow-500"
                placeholder="Viết bài giới thiệu sản phẩm chuẩn SEO..."
                value={formData.description || ""} onChange={(e) => handleChange("description", e.target.value)} />
          </div>
        </div>
      </div>

      {/* HÌNH ẢNH */}
      <div className="bg-white p-6 rounded-md shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <ImageIcon size={20} className="text-yellow-600" /> Hình ảnh
        </h3>
        <div className="flex flex-wrap gap-4">
            {[0,1,2,3,4,5,6,7,8].map((index) => (
                <div key={index} className="w-24 h-24 border border-dashed border-gray-300 rounded hover:border-yellow-500 relative group bg-gray-50 flex items-center justify-center overflow-hidden">
                    {uploadingIndex === index ? (
                        <div className="animate-spin text-yellow-600"><Loader2 size={24}/></div>
                    ) : formData.images?.[index] ? (
                        <>
                            <img src={formData.images[index]} className="w-full h-full object-cover" />
                            <button type="button" onClick={() => removeImage(index)}
                                className="absolute top-0 right-0 bg-red-500 text-white p-0.5 rounded-bl opacity-0 group-hover:opacity-100 transition">
                                <X size={14} />
                            </button>
                        </>
                    ) : (
                        <label className="cursor-pointer w-full h-full flex flex-col items-center justify-center text-gray-400 hover:text-yellow-600 hover:bg-yellow-50 transition">
                            <Plus size={20} />
                            <input type="file" accept="image/*" className="hidden"
                                onChange={(e) => { if(e.target.files?.[0]) handleFileUpload(index, e.target.files[0]); }} />
                        </label>
                    )}
                </div>
            ))}
        </div>
      </div>

      {/* VẬN CHUYỂN */}
      <div className="bg-white p-6 rounded-md shadow-sm border border-gray-200">
        <h3 className="text-lg font-bold text-gray-800 mb-6 flex items-center gap-2">
          <Truck size={20} className="text-yellow-600" /> Vận chuyển
        </h3>
        <div className="grid grid-cols-12 gap-6 items-center">
          <div className="col-span-2 text-right text-sm text-gray-600 font-medium">Cân nặng (gr)</div>
          <div className="col-span-4">
             <input type="number" className="w-full border border-gray-300 rounded px-3 py-2 text-sm outline-none"
                value={formData.weight || 0} onChange={(e) => handleChange("weight", parseInt(e.target.value))} />
          </div>
        </div>
      </div>

      {/* FOOTER */}
      <div className="fixed bottom-0 right-0 left-64 bg-white border-t p-4 shadow-lg flex justify-end gap-4 z-50">
         <button type="button" onClick={() => router.back()} className="px-6 py-2 rounded text-sm font-medium border hover:bg-gray-50">Hủy</button>
         <button type="submit" disabled={loading}
            className="px-6 py-2 rounded text-sm font-medium bg-yellow-500 text-white hover:bg-yellow-600 shadow-sm flex items-center gap-2">
            {loading ? <Loader2 className="animate-spin" size={16} /> : <Save size={16} />}
            {loading ? "Đang xử lý..." : "Lưu & Hiển thị"}
         </button>
      </div>

    </form>
  );
}
