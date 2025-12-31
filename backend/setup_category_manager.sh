#!/bin/bash

BACKEND_DIR="/var/www/lica-project/backend"
ADMIN_DIR="/var/www/lica-project/apps/admin"

echo ">>> BẮT ĐẦU TRIỂN KHAI QUẢN LÝ DANH MỤC (CATEGORIES)..."

# ====================================================
# 1. BACKEND: NÂNG CẤP CATEGORY CONTROLLER
# ====================================================
echo ">>> [1/3] Upgrading Backend CategoryController..."
CTRL_FILE="$BACKEND_DIR/Modules/Product/app/Http/Controllers/CategoryController.php"

cat > "$CTRL_FILE" <<PHP
<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Category;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    // Lấy danh sách (Có thể filter theo parent)
    public function index(Request \$request)
    {
        \$query = Category::with('parent');
        
        if (\$request->has('q')) {
            \$query->where('name', 'like', "%{\$request->q}%");
        }

        // Sắp xếp: Cha trước con sau
        \$data = \$query->orderBy('parent_id', 'asc')->orderBy('id', 'desc')->get();
        
        // Map thêm level để frontend dễ hiển thị
        \$mapped = \$data->map(function(\$item) {
            \$item->level = \$item->parent_id ? 1 : 0; // Đơn giản hóa level cho demo
            return \$item;
        });

        return response()->json(['status' => 200, 'data' => \$mapped]);
    }

    public function store(Request \$request)
    {
        \$request->validate([
            'name' => 'required|string|max:255',
            'parent_id' => 'nullable|exists:categories,id'
        ]);

        \$slug = Str::slug(\$request->name);
        // Đảm bảo slug unique
        if (Category::where('slug', \$slug)->exists()) {
            \$slug .= '-' . time();
        }

        \$category = Category::create([
            'name' => \$request->name,
            'slug' => \$slug,
            'parent_id' => \$request->parent_id
        ]);

        return response()->json(['status' => 201, 'data' => \$category]);
    }

    public function show(\$id)
    {
        \$category = Category::find(\$id);
        if (!\$category) return response()->json(['message' => 'Not found'], 404);
        return response()->json(['status' => 200, 'data' => \$category]);
    }

    public function update(Request \$request, \$id)
    {
        \$category = Category::find(\$id);
        if (!\$category) return response()->json(['message' => 'Not found'], 404);

        \$request->validate([
            'name' => 'string|max:255',
            'parent_id' => 'nullable|exists:categories,id'
        ]);
        
        // Không cho phép category làm cha của chính nó
        if (\$request->parent_id == \$id) {
            return response()->json(['message' => 'Không thể chọn chính mình làm cha'], 400);
        }

        \$data = \$request->all();
        if (\$request->has('name')) {
            \$data['slug'] = Str::slug(\$request->name);
        }

        \$category->update(\$data);
        return response()->json(['status' => 200, 'data' => \$category]);
    }

    public function destroy(\$id)
    {
        // Cập nhật các con về null trước khi xóa cha (để tránh lỗi)
        Category::where('parent_id', \$id)->update(['parent_id' => null]);
        Category::destroy(\$id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
PHP

# ====================================================
# 2. BACKEND: CẬP NHẬT ROUTE
# ====================================================
echo ">>> [2/3] Updating Routes..."
ROUTE_FILE="$BACKEND_DIR/Modules/Product/routes/api.php"

# Chúng ta cần đảm bảo route category dùng apiResource để đủ CRUD
cat > "$ROUTE_FILE" <<PHP
<?php

use Illuminate\Support\Facades\Route;
use Modules\Product\Http\Controllers\ProductController;
use Modules\Product\Http\Controllers\CategoryController;
use Modules\Product\Http\Controllers\BrandController;
use Modules\Product\Http\Controllers\OriginController;
use Modules\Product\Http\Controllers\UnitController;
use Modules\Product\Http\Controllers\SkinTypeController;

// 1. Nhóm API Sản phẩm
Route::prefix('v1/product')->group(function () {
    Route::apiResource('brands', BrandController::class);
    Route::apiResource('origins', OriginController::class);
    Route::apiResource('units', UnitController::class);
    Route::apiResource('skin-types', SkinTypeController::class);

    // Route Product chính (Đặt cuối để tránh conflict)
    Route::get('/', [ProductController::class, 'index']);
    Route::post('/', [ProductController::class, 'store']);
    Route::get('/{id}', [ProductController::class, 'show']);
    Route::put('/{id}', [ProductController::class, 'update']);
    Route::delete('/{id}', [ProductController::class, 'destroy']);
});

// 2. Nhóm API Danh mục (Full CRUD)
Route::prefix('v1/category')->group(function () {
    Route::get('/', [CategoryController::class, 'index']);
    Route::post('/', [CategoryController::class, 'store']);
    Route::get('/{id}', [CategoryController::class, 'show']);
    Route::put('/{id}', [CategoryController::class, 'update']);
    Route::delete('/{id}', [CategoryController::class, 'destroy']);
});
PHP

# Clear cache route
cd "$BACKEND_DIR"
php artisan route:clear

# ====================================================
# 3. FRONTEND: TẠO TRANG QUẢN LÝ DANH MỤC
# ====================================================
echo ">>> [3/3] Creating Frontend Category Page..."
PAGE_DIR="$ADMIN_DIR/app/products/categories"
mkdir -p "$PAGE_DIR"

cat > "$PAGE_DIR/page.tsx" <<TSX
"use client";
import { useState, useEffect } from "react";
import axios from "axios";
import { Plus, Edit, Trash2, FolderTree, Save, X, Loader2 } from "lucide-react";

interface Category {
  id: number;
  name: string;
  slug: string;
  parent_id: number | null;
  parent?: { name: string };
}

export default function CategoryManager() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [loading, setLoading] = useState(true);
  const [modalOpen, setModalOpen] = useState(false);
  
  // Form State
  const [editingId, setEditingId] = useState<number | null>(null);
  const [name, setName] = useState("");
  const [parentId, setParentId] = useState<string>("");

  const apiUrl = \`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/category\`;

  const fetchCategories = async () => {
    try {
      setLoading(true);
      const res = await axios.get(apiUrl);
      setCategories(res.data.data || []);
    } catch (err) { console.error(err); } 
    finally { setLoading(false); }
  };

  useEffect(() => { fetchCategories(); }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const payload = { 
        name, 
        parent_id: parentId ? Number(parentId) : null 
    };

    try {
      if (editingId) {
        await axios.put(\`\${apiUrl}/\${editingId}\`, payload);
      } else {
        await axios.post(apiUrl, payload);
      }
      setModalOpen(false);
      resetForm();
      fetchCategories();
    } catch (err) { alert("Lỗi lưu danh mục!"); }
  };

  const handleDelete = async (id: number) => {
    if (!confirm("Bạn chắc chắn xóa danh mục này?")) return;
    try {
      await axios.delete(\`\${apiUrl}/\${id}\`);
      fetchCategories();
    } catch (err) { alert("Lỗi xóa!"); }
  };

  const openEdit = (cat: Category) => {
    setEditingId(cat.id);
    setName(cat.name);
    setParentId(cat.parent_id ? String(cat.parent_id) : "");
    setModalOpen(true);
  };

  const resetForm = () => {
    setEditingId(null);
    setName("");
    setParentId("");
  };

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2">
            <FolderTree className="text-blue-600"/> Quản lý Phân loại (Category)
        </h1>
        <button onClick={() => { resetForm(); setModalOpen(true); }} 
            className="bg-blue-600 text-white px-4 py-2 rounded-md flex items-center gap-2 hover:bg-blue-700 shadow">
          <Plus size={18} /> Thêm danh mục
        </button>
      </div>

      <div className="bg-white rounded-lg shadow border overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-gray-500"><Loader2 className="animate-spin inline"/> Đang tải...</div>
        ) : (
          <table className="w-full text-sm text-left">
            <thead className="bg-gray-50 text-gray-700 uppercase font-medium">
              <tr>
                <th className="px-6 py-3">ID</th>
                <th className="px-6 py-3">Tên danh mục</th>
                <th className="px-6 py-3">Danh mục cha</th>
                <th className="px-6 py-3">Slug (Đường dẫn)</th>
                <th className="px-6 py-3 text-right">Hành động</th>
              </tr>
            </thead>
            <tbody>
              {categories.map((cat) => (
                <tr key={cat.id} className="border-b hover:bg-gray-50">
                  <td className="px-6 py-4 text-gray-500">{cat.id}</td>
                  <td className="px-6 py-4 font-medium text-gray-900 flex items-center gap-2">
                     {cat.parent_id ? <span className="text-gray-300">└──</span> : <span className="text-blue-500">■</span>} 
                     {cat.name}
                  </td>
                  <td className="px-6 py-4 text-gray-600">
                    {cat.parent ? <span className="bg-gray-100 px-2 py-1 rounded text-xs">{cat.parent.name}</span> : "-"}
                  </td>
                  <td className="px-6 py-4 font-mono text-gray-500 text-xs">{cat.slug}</td>
                  <td className="px-6 py-4 text-right flex justify-end gap-3">
                    <button onClick={() => openEdit(cat)} className="text-blue-600 hover:bg-blue-50 p-1 rounded"><Edit size={16}/></button>
                    <button onClick={() => handleDelete(cat.id)} className="text-red-600 hover:bg-red-50 p-1 rounded"><Trash2 size={16}/></button>
                  </td>
                </tr>
              ))}
              {categories.length === 0 && <tr><td colSpan={5} className="p-6 text-center text-gray-500">Chưa có danh mục nào</td></tr>}
            </tbody>
          </table>
        )}
      </div>

      {/* MODAL FORM */}
      {modalOpen && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 animate-in fade-in">
          <div className="bg-white p-6 rounded-lg w-96 shadow-xl">
            <div className="flex justify-between items-center mb-4">
                <h3 className="text-lg font-bold">{editingId ? "Cập nhật" : "Thêm mới"} Danh mục</h3>
                <button onClick={() => setModalOpen(false)}><X size={20} className="text-gray-400 hover:text-red-500"/></button>
            </div>
            
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-1 text-gray-700">Tên danh mục <span className="text-red-500">*</span></label>
                <input required value={name} onChange={e => setName(e.target.value)} 
                    className="w-full border border-gray-300 p-2 rounded focus:ring-2 ring-blue-500 outline-none" 
                    placeholder="VD: Kem chống nắng" />
              </div>
              
              <div>
                <label className="block text-sm font-medium mb-1 text-gray-700">Danh mục cha</label>
                <select value={parentId} onChange={e => setParentId(e.target.value)} 
                    className="w-full border border-gray-300 p-2 rounded focus:ring-2 ring-blue-500 outline-none bg-white">
                    <option value="">-- Không có (Danh mục gốc) --</option>
                    {categories
                        .filter(c => c.id !== editingId) // Không được chọn chính mình làm cha
                        .map(c => (
                        <option key={c.id} value={c.id}>{c.name}</option>
                    ))}
                </select>
              </div>

              <div className="flex justify-end gap-2 mt-6 pt-4 border-t">
                <button type="button" onClick={() => setModalOpen(false)} className="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded font-medium">Hủy</button>
                <button type="submit" className="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700 flex items-center gap-2 font-medium shadow-sm">
                    <Save size={16}/> Lưu lại
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

# Rebuild Admin
echo ">>> Rebuilding Frontend..."
cd "$ADMIN_DIR"
npm run build
pm2 restart lica-admin 2>/dev/null

echo "--------------------------------------------------------"
echo "✅ ĐÃ TẠO XONG QUẢN LÝ DANH MỤC!"
echo "👉 Truy cập: https://admin.lica.vn/products/categories"
echo "👉 Hoặc bấm vào menu 'Sản phẩm' -> 'Phân loại (Category)'"
echo "--------------------------------------------------------"
