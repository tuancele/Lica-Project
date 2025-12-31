import ProductForm from "@/components/ProductForm";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";

export default function CreateProduct() {
  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex items-center gap-2 mb-6 text-gray-600 hover:text-gray-900 w-fit">
        <ArrowLeft size={18} />
        <Link href="/products">Quay lại danh sách</Link>
      </div>
      <h1 className="text-2xl font-bold mb-6">Thêm sản phẩm mới</h1>
      <ProductForm />
    </div>
  );
}
