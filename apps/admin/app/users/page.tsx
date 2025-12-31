"use client";

import { useState, useEffect, useCallback } from "react";
import axios from "axios";
import { Search, Trash2, User, Mail, Phone, Calendar, Shield, Eye, Loader2 } from "lucide-react";
import Link from "next/link";

export default function UsersPage() {
  const [users, setUsers] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [pagination, setPagination] = useState<any>(null);
  const [search, setSearch] = useState("");

  const fetchUsers = useCallback(async (page = 1) => {
    try {
      setLoading(true);
      const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/users`, {
        params: { page, q: search }
      });
      setUsers(res.data.data.data);
      setPagination(res.data.data);
    } catch (err) { console.error(err); } finally { setLoading(false); }
  }, [search]);

  useEffect(() => {
    const timer = setTimeout(() => fetchUsers(), 500);
    return () => clearTimeout(timer);
  }, [fetchUsers]);

  const handleDelete = async (id: number) => {
    if (!confirm("Bạn chắc chắn muốn xóa?")) return;
    try {
        await axios.delete(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/users/${id}`);
        fetchUsers();
    } catch (err) { alert("Lỗi khi xóa."); }
  };

  return (
    <div className="p-6 max-w-7xl mx-auto bg-gray-50 min-h-screen font-sans">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-800">Thành viên</h1>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="p-4 border-b border-gray-100 flex gap-4 bg-white">
            <div className="relative flex-1 max-w-md">
                <Search className="absolute left-3 top-2.5 text-gray-400" size={18} />
                <input type="text" placeholder="Tìm thành viên..." className="w-full pl-10 pr-4 py-2 border rounded-lg outline-none focus:ring-2 focus:ring-blue-500"
                    value={search} onChange={(e) => setSearch(e.target.value)} />
            </div>
        </div>

        <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
                <thead className="bg-gray-50 text-gray-600 text-xs uppercase font-semibold">
                    <tr>
                        <th className="px-6 py-4">Thành viên</th>
                        <th className="px-6 py-4">Liên hệ</th>
                        <th className="px-6 py-4">Hạng</th>
                        <th className="px-6 py-4">Ngày tham gia</th>
                        <th className="px-6 py-4 text-right">Hành động</th>
                    </tr>
                </thead>
                <tbody className="divide-y divide-gray-100 text-sm">
                    {loading ? (
                        <tr><td colSpan={5} className="p-10 text-center"><Loader2 className="animate-spin inline text-blue-600"/></td></tr>
                    ) : users.length > 0 ? (
                        users.map((user) => (
                            <tr key={user.id} className="hover:bg-gray-50 transition group">
                                <td className="px-6 py-4">
                                    <Link href={`/users/${user.id}`} className="flex items-center gap-3 group-hover:text-blue-600">
                                        <div className="w-10 h-10 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center font-bold uppercase text-sm">
                                            {user.name ? user.name[0] : <User size={16}/>}
                                        </div>
                                        <div>
                                            <div className="font-bold text-gray-900 group-hover:text-blue-600 transition">{user.name || "N/A"}</div>
                                            <div className="text-xs text-gray-500 font-mono">@{user.username}</div>
                                        </div>
                                    </Link>
                                </td>
                                <td className="px-6 py-4">
                                    <div className="space-y-1 text-gray-600">
                                        {user.email && <div className="flex items-center gap-2"><Mail size={14}/> {user.email}</div>}
                                        {user.phone && <div className="flex items-center gap-2"><Phone size={14}/> {user.phone}</div>}
                                    </div>
                                </td>
                                <td className="px-6 py-4">
                                    <span className="px-2 py-1 rounded text-xs font-bold uppercase bg-gray-100 text-gray-600">{user.membership_tier}</span>
                                </td>
                                <td className="px-6 py-4 text-gray-600">{new Date(user.created_at).toLocaleDateString('vi-VN')}</td>
                                <td className="px-6 py-4 text-right">
                                    <div className="flex justify-end gap-2">
                                        <Link href={`/users/${user.id}`} className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg"><Eye size={18}/></Link>
                                        <button onClick={() => handleDelete(user.id)} className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg"><Trash2 size={18}/></button>
                                    </div>
                                </td>
                            </tr>
                        ))
                    ) : (
                        <tr><td colSpan={5} className="p-10 text-center text-gray-500">Không tìm thấy thành viên.</td></tr>
                    )}
                </tbody>
            </table>
        </div>
      </div>
    </div>
  );
}
