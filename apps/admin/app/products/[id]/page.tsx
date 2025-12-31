"use client";

import { useEffect, useState, use } from "react";
import ProductForm from "@/components/ProductForm";
import axios from "axios";
import { Loader2, ArrowLeft } from "lucide-react";
import Link from "next/link";
import { Product } from "@/types/product";

export default function EditProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  
  const [product, setProduct] = useState<Product | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const fetchProduct = async () => {
      try {
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/${id}`);
        setProduct(res.data.data);
      } catch (err) {
        console.error(err);
        setError("Không tìm thấy sản phẩm.");
      } finally {
        setLoading(false);
      }
    };
    if (id) fetchProduct();
  }, [id]);

  if (loading) return <div className="flex h-screen items-center justify-center"><Loader2 className="animate-spin text-blue-600" /></div>;

  if (error || !product) {
    return (
      <div className="p-8 text-center">
        <h2 className="text-red-600 font-bold mb-2">Lỗi</h2>
        <p className="mb-4">{error}</p>
        <Link href="/products" className="text-blue-600 hover:underline flex items-center justify-center gap-2"><ArrowLeft size={16} /> Quay lại</Link>
      </div>
    );
  }

  return (
    <div className="p-6">
      <div className="flex items-center gap-3 mb-6">
        <Link href="/products" className="p-2 rounded-full hover:bg-gray-100 text-gray-500"><ArrowLeft size={20}/></Link>
        <h1 className="text-2xl font-bold text-gray-800">Sửa sản phẩm: {product.name}</h1>
      </div>
      <ProductForm initialData={product} isEdit={true} />
    </div>
  );
}
