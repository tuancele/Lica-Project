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

  const apiUrl = `${process.env.NEXT_PUBLIC_API_URL}/api/v1/category`;

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
        await axios.put(`${apiUrl}/${editingId}`, payload);
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
      await axios.delete(`${apiUrl}/${id}`);
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
