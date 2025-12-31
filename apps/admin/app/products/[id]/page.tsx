"use client";

import { useState, useEffect } from "react";
import { useParams } from "next/navigation";
import axios from "axios";
import ProductForm from "@/components/ProductForm";
import { Loader2, AlertCircle } from "lucide-react";

export default function EditProductPage() {
  // useParams() là cách chuẩn nhất trong Client Component để lấy ID
  const params = useParams();
  const id = params?.id; 

  const [product, setProduct] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!id) return;

    const fetchProduct = async () => {
      try {
        setLoading(true);
        // Gọi API lấy chi tiết sản phẩm
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/${id}`);
        setProduct(res.data.data);
      } catch (err) {
        console.error("Lỗi tải sản phẩm:", err);
        setError("Không tìm thấy sản phẩm hoặc lỗi kết nối.");
      } finally {
        setLoading(false);
      }
    };

    fetchProduct();
  }, [id]);

  if (loading) {
    return (
      <div className="flex h-[50vh] items-center justify-center flex-col gap-4 text-gray-500">
        <Loader2 className="animate-spin text-blue-600" size={32} />
        <p>Đang tải dữ liệu sản phẩm...</p>
      </div>
    );
  }

  if (error || !product) {
    return (
      <div className="flex h-[50vh] items-center justify-center flex-col gap-4 text-red-500">
        <AlertCircle size={48} />
        <h2 className="text-xl font-bold">Lỗi!</h2>
        <p>{error || "Dữ liệu không tồn tại"}</p>
        <button onClick={() => window.history.back()} className="text-blue-600 hover:underline">Quay lại</button>
      </div>
    );
  }

  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold text-gray-800 mb-6 flex items-center gap-2">
        ✏️ Chỉnh sửa sản phẩm
      </h1>
      {/* Truyền dữ liệu vào Form và bật chế độ Edit */}
      <ProductForm initialData={product} isEdit={true} />
    </div>
  );
}
