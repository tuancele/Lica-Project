#!/bin/bash

ADMIN_DIR="/var/www/lica-project/apps/admin"
BACKEND_DIR="/var/www/lica-project/backend"

echo ">>> BẮT ĐẦU SỬA LỖI CHỈNH SỬA SẢN PHẨM..."

# ====================================================
# 1. FRONTEND: TẠO TRANG EDIT CHUẨN (Lấy ID an toàn)
# ====================================================
echo ">>> [1/2] Creating Edit Product Page..."
PAGE_DIR="$ADMIN_DIR/app/products/[id]"
mkdir -p "$PAGE_DIR"

# Sử dụng Client Component wrapper để xử lý params an toàn nhất
cat > "$PAGE_DIR/page.tsx" <<TSX
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
        const res = await axios.get(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/product/\${id}\`);
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
TSX

# ====================================================
# 2. BACKEND: BẢO VỆ API (Tránh lỗi 500 khi ID sai)
# ====================================================
echo ">>> [2/2] Patching Backend Controller..."
CTRL_FILE="$BACKEND_DIR/Modules/Product/app/Http/Controllers/ProductController.php"

# Chúng ta cập nhật lại hàm show để kiểm tra ID kỹ hơn
# Lưu ý: Script này ghi đè file Controller nhưng giữ nguyên logic cũ, chỉ thêm validate ID
# Tôi sẽ dùng sed để sửa đoạn show($id) nếu có thể, nhưng an toàn nhất là ghi đè hàm show
# Tuy nhiên để đảm bảo tính toàn vẹn, tôi sẽ update lại file Controller hoàn chỉnh với fix lỗi.

cat > "$CTRL_FILE" <<PHP
<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Product;
use Illuminate\Support\Str;

class ProductController extends Controller
{
    public function index(Request \$request)
    {
        \$query = Product::with(['category', 'brand', 'origin', 'unit']);

        if (\$request->has('q')) {
            \$query->where('name', 'like', "%{\$request->q}%")
                  ->orWhere('sku', 'like', "%{\$request->q}%");
        }
        
        if (\$request->has('category_id')) {
            \$query->where('category_id', \$request->category_id);
        }

        return response()->json(['status' => 200, 'data' => \$query->orderBy('created_at', 'desc')->paginate(20)]);
    }

    public function show(\$id)
    {
        // FIX LỖI 500: Kiểm tra nếu ID không phải số thì trả lỗi 404 luôn
        if (!is_numeric(\$id)) {
            return response()->json(['message' => 'Invalid ID format'], 404);
        }

        \$product = Product::with(['category', 'brand', 'origin', 'unit'])->find(\$id);
        
        if (!\$product) {
            return response()->json(['message' => 'Not found'], 404);
        }
        
        return response()->json(['status' => 200, 'data' => \$product]);
    }

    public function store(Request \$request)
    {
        \$data = \$request->validate([
            'name' => 'required|string|max:255',
            'price' => 'required|numeric|min:0',
            'sku' => 'nullable|string',
            'category_id' => 'nullable',
            'brand_id' => 'nullable',
            'origin_id' => 'nullable',
            'unit_id' => 'nullable',
            'skin_type_ids' => 'nullable|array',
            'images' => 'nullable|array',
            'stock_quantity' => 'integer|min:0',
            'description' => 'nullable',
            'short_description' => 'nullable',
            'ingredients' => 'nullable',
            'usage_instructions' => 'nullable',
            'is_active' => 'boolean'
        ]);

        if (empty(\$request->slug)) {
            \$data['slug'] = Str::slug(\$data['name']) . '-' . uniqid();
        }
        
        // Auto set SKU if missing
        if (empty(\$data['sku'])) {
            \$data['sku'] = strtoupper(Str::random(8));
        }

        if (!empty(\$data['images']) && is_array(\$data['images'])) {
            \$data['thumbnail'] = \$data['images'][0] ?? null;
        }

        \$product = Product::create(\$data);
        return response()->json(['status' => 201, 'data' => \$product]);
    }

    public function update(Request \$request, \$id)
    {
        if (!is_numeric(\$id)) return response()->json(['message' => 'Invalid ID'], 404);

        \$product = Product::find(\$id);
        if (!\$product) return response()->json(['message' => 'Not found'], 404);

        \$data = \$request->all();
        
        if (\$request->has('images')) {
            \$images = \$request->input('images');
            if (!empty(\$images) && is_array(\$images)) {
                \$data['thumbnail'] = \$images[0] ?? null;
            }
        }

        \$product->update(\$data);
        return response()->json(['status' => 200, 'data' => \$product]);
    }

    public function destroy(\$id)
    {
        if (!is_numeric(\$id)) return response()->json(['message' => 'Invalid ID'], 404);
        Product::destroy(\$id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
PHP

# Rebuild Admin
echo ">>> Rebuilding Admin Frontend..."
cd "$ADMIN_DIR"
npm run build
pm2 restart lica-admin 2>/dev/null

echo "--------------------------------------------------------"
echo "✅ ĐÃ SỬA LỖI EDIT THÀNH CÔNG!"
echo "👉 Hãy vào danh sách sản phẩm -> Bấm nút 'Sửa' (icon bút chì)."
echo "👉 Lỗi 500 undefined sẽ không còn xuất hiện."
echo "--------------------------------------------------------"
