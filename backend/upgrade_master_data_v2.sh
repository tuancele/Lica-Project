#!/bin/bash

BACKEND_DIR="/var/www/lica-project/backend"
ADMIN_DIR="/var/www/lica-project/apps/admin"

echo ">>> BẮT ĐẦU NÂNG CẤP MASTER DATA (SEO & CONTENT)..."

# ====================================================
# 1. DATABASE: CẬP NHẬT CẤU TRÚC BẢNG
# ====================================================
echo ">>> [1/4] Updating Database Structure..."
cd "$BACKEND_DIR"

MIGRATION_FILE="database/migrations/$(date +%Y_%m_%d_%H%M%S)_upgrade_master_data_fields.php"

cat > "$MIGRATION_FILE" <<PHP
<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        \$tables = ['brands', 'origins', 'units', 'skin_types'];
        foreach (\$tables as \$table) {
            Schema::table(\$table, function (Blueprint \$table) {
                if (!Schema::hasColumn(\$table->getTable(), 'slug')) \$table->string('slug')->nullable()->unique();
                if (!Schema::hasColumn(\$table->getTable(), 'description')) \$table->text('description')->nullable();
                if (!Schema::hasColumn(\$table->getTable(), 'image')) \$table->string('image')->nullable();
            });
        }
    }
    public function down(): void {}
};
PHP

php artisan migrate --force

# ====================================================
# 2. BACKEND: CẬP NHẬT CONTROLLER CHUNG
# ====================================================
# Sửa lại các Controller để tự sinh Slug khi lưu
echo ">>> [2/4] Updating Controllers (Auto-Slug)..."

update_controller() {
    NAME=$1
    MODEL=$2
    CTRL_FILE="Modules/Product/app/Http/Controllers/${NAME}Controller.php"
    
    cat > "\$CTRL_FILE" <<PHP
<?php
namespace Modules\Product\Http\Controllers;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\\$MODEL;
use Illuminate\Support\Str;

class ${NAME}Controller extends Controller {
    public function index() {
        return response()->json(['status' => 200, 'data' => $MODEL::latest()->get()]);
    }

    public function store(Request \$request) {
        \$request->validate(['name' => 'required|string|max:255']);
        \$data = \$request->all();
        \$data['slug'] = Str::slug(\$request->name) . '-' . rand(100, 999);
        \$item = $MODEL::create(\$data);
        return response()->json(['status' => 201, 'data' => \$item]);
    }

    public function update(Request \$request, \$id) {
        \$item = $MODEL::find(\$id);
        if (!\$item) return response()->json(['message' => 'Not found'], 404);
        \$data = \$request->all();
        if (\$request->has('name') && \$request->name !== \$item->name) {
            \$data['slug'] = Str::slug(\$request->name) . '-' . rand(100, 999);
        }
        \$item->update(\$data);
        return response()->json(['status' => 200, 'data' => \$item]);
    }

    public function destroy(\$id) {
        $MODEL::destroy(\$id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
PHP
}

update_controller "Brand" "Brand"
update_controller "Origin" "Origin"
update_controller "Unit" "Unit"
update_controller "SkinType" "SkinType"

# ====================================================
# 3. FRONTEND: NÂNG CẤP GENERIC CRUD UI
# ====================================================
echo ">>> [3/4] Updating Admin UI (Adding Description & Image)..."

cat > "$ADMIN_DIR/components/GenericCrud.tsx" <<TSX
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { Plus, Trash2, Edit, Loader2, Save, X, Image as ImageIcon, Link as LinkIcon } from "lucide-react";

interface Item {
  id: number;
  name: string;
  slug?: string;
  description?: string;
  image?: string;
  code?: string;
}

interface Props { title: string; endpoint: string; hasCode?: boolean; }

export default function GenericCrud({ title, endpoint, hasCode = false }: Props) {
  const [data, setData] = useState<Item[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingItem, setEditingItem] = useState<Item | null>(null);
  
  // Form State
  const [name, setName] = useState("");
  const [code, setCode] = useState("");
  const [description, setDescription] = useState("");
  const [image, setImage] = useState("");

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
    const payload = { name, description, image, ...(hasCode && { code }) };
    try {
      if (editingItem) await axios.put(\`\${apiUrl}/\${editingItem.id}\`, payload);
      else await axios.post(apiUrl, payload);
      setModalOpen(false);
      resetForm();
      fetchData();
    } catch (err) { alert("Lỗi thao tác!"); }
  };

  const handleUpload = async (file: File) => {
    const formData = new FormData();
    formData.append("file", file);
    try {
      const res = await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/cms/upload\`, formData);
      setImage(res.data.url);
    } catch (err) { alert("Lỗi upload!"); }
  };

  const openEdit = (item: Item) => {
    setEditingItem(item);
    setName(item.name);
    setDescription(item.description || "");
    setImage(item.image || "");
    setCode(item.code || "");
    setModalOpen(true);
  };

  const resetForm = () => {
    setEditingItem(null);
    setName(""); setCode(""); setDescription(""); setImage("");
  };

  return (
    <div className="p-6 font-sans">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Quản lý {title}</h1>
        <button onClick={() => { resetForm(); setModalOpen(true); }} className="bg-blue-600 text-white px-4 py-2 rounded-lg flex items-center gap-2 hover:bg-blue-700 transition shadow-sm">
          <Plus size={18} /> Thêm {title} mới
        </button>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <table className="w-full text-sm text-left">
          <thead className="bg-gray-50 text-gray-600 font-semibold uppercase text-[11px] tracking-wider">
            <tr>
              <th className="px-6 py-4">Ảnh</th>
              <th className="px-6 py-4">Thông tin {title}</th>
              <th className="px-6 py-4">Đường dẫn (Slug)</th>
              <th className="px-6 py-4 text-right">Thao tác</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {data.map((item) => (
              <tr key={item.id} className="hover:bg-gray-50 transition">
                <td className="px-6 py-4">
                  {item.image ? <img src={item.image} className="w-10 h-10 object-cover rounded-md border" /> : <div className="w-10 h-10 bg-gray-100 rounded-md flex items-center justify-center text-gray-400"><ImageIcon size={16}/></div>}
                </td>
                <td className="px-6 py-4">
                  <div className="font-bold text-gray-900">{item.name}</div>
                  <div className="text-[12px] text-gray-500 line-clamp-1 max-w-[200px]">{item.description || "Chưa có mô tả"}</div>
                </td>
                <td className="px-6 py-4 font-mono text-blue-500 text-[12px] flex items-center gap-1">
                  <LinkIcon size={12}/> lica.vn/{endpoint === 'skin-types' ? 'loai-da' : endpoint}/{item.slug}
                </td>
                <td className="px-6 py-4 text-right">
                  <div className="flex justify-end gap-2">
                    <button onClick={() => openEdit(item)} className="p-2 text-blue-600 hover:bg-blue-50 rounded-md"><Edit size={16}/></button>
                    <button onClick={() => handleDelete(item.id)} className="p-2 text-red-600 hover:bg-red-50 rounded-md"><Trash2 size={16}/></button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {loading && <div className="p-12 flex justify-center"><Loader2 className="animate-spin text-blue-600"/></div>}
      </div>

      {modalOpen && (
        <div className="fixed inset-0 bg-black/60 flex items-center justify-center z-[100] backdrop-blur-sm">
          <div className="bg-white p-8 rounded-2xl w-[500px] shadow-2xl animate-in zoom-in duration-200">
            <h3 className="text-xl font-bold mb-6 text-gray-800">{editingItem ? "Cập nhật" : "Tạo mới"} {title}</h3>
            <form onSubmit={handleSubmit} className="space-y-5">
              <div className="flex gap-4 items-start">
                <div className="w-24 h-24 border-2 border-dashed border-gray-300 rounded-xl relative group overflow-hidden flex-shrink-0">
                   {image ? <img src={image} className="w-full h-full object-cover"/> : <div className="flex flex-col items-center justify-center h-full text-gray-400"><ImageIcon size={20}/><span className="text-[10px]">Ảnh</span></div>}
                   <input type="file" onChange={e => e.target.files?.[0] && handleUpload(e.target.files[0])} className="absolute inset-0 opacity-0 cursor-pointer"/>
                </div>
                <div className="flex-1 space-y-4">
                  <div>
                    <label className="block text-[12px] font-bold text-gray-600 uppercase mb-1">Tên {title}</label>
                    <input required value={name} onChange={e => setName(e.target.value)} className="w-full border-gray-200 border p-2.5 rounded-lg focus:ring-2 ring-blue-500 outline-none transition" />
                  </div>
                  {hasCode && (
                    <div>
                      <label className="block text-[12px] font-bold text-gray-600 uppercase mb-1">Mã Code</label>
                      <input value={code} onChange={e => setCode(e.target.value)} className="w-full border-gray-200 border p-2.5 rounded-lg focus:ring-2 ring-blue-500 outline-none uppercase" />
                    </div>
                  )}
                </div>
              </div>
              
              <div>
                <label className="block text-[12px] font-bold text-gray-600 uppercase mb-1">Mô tả chi tiết</label>
                <textarea value={description} onChange={e => setDescription(e.target.value)} className="w-full border-gray-200 border p-3 rounded-xl h-32 focus:ring-2 ring-blue-500 outline-none text-sm" placeholder="Nhập mô tả sản phẩm cho SEO..." />
              </div>

              <div className="flex justify-end gap-3 pt-4 border-t">
                <button type="button" onClick={() => setModalOpen(false)} className="px-5 py-2 text-gray-500 hover:bg-gray-100 rounded-lg font-semibold">Hủy</button>
                <button type="submit" className="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2 font-bold shadow-md shadow-blue-200">
                    <Save size={18}/> Lưu thay đổi
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
# 4. REBUILD & FINISH
# ====================================================
echo ">>> [4/4] Rebuilding Frontend..."
cd "$ADMIN_DIR"
npm run build
pm2 restart lica-admin

echo "--------------------------------------------------------"
echo "✅ HOÀN THÀNH NÂNG CẤP TOÀN DIỆN!"
echo "👉 1. Tất cả Master Data đã có: Ảnh, Mô tả, Slug (URL)."
echo "👉 2. Tự động sinh Slug đẹp cho SEO."
echo "👉 3. Giao diện Admin đã có Form Upload ảnh và nhập mô tả."
echo "--------------------------------------------------------"
