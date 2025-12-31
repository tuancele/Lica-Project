"use client";
import { useEffect, useState } from "react";
import axios from "axios";
import ProductForm from "@/components/ProductForm";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";
import { Product } from "@/types/product";

export default function EditProduct({ params }: { params: { id: string } }) {
  const [product, setProduct] = useState<Product | null>(null);

  useEffect(() => {
    // Fetch dữ liệu sản phẩm cần sửa
    axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/${params.id}`)
      .then(res => setProduct(res.data))
      .catch(err => alert("Không tìm thấy sản phẩm"));
  }, [params.id]);

  if (!product) return <div>Đang tải dữ liệu...</div>;

  return (
    <div className="max-w-4xl mx-auto">
       <div className="flex items-center gap-2 mb-6 text-gray-600 hover:text-gray-900 w-fit">
        <ArrowLeft size={18} />
        <Link href="/products">Quay lại danh sách</Link>
      </div>
      <h1 className="text-2xl font-bold mb-6">Chỉnh sửa: {product.name}</h1>
      <ProductForm initialData={product} isEdit={true} />
    </div>
  );
}
