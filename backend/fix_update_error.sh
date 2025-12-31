#!/bin/bash

BACKEND_DIR="/var/www/lica-project/backend"
CTRL_FILE="$BACKEND_DIR/Modules/Product/app/Http/Controllers/ProductController.php"

echo ">>> BẮT ĐẦU SỬA LỖI UPDATE SẢN PHẨM (FIX 500)..."

# Ghi đè lại ProductController với logic xử lý dữ liệu chặt chẽ hơn
cat > "$CTRL_FILE" <<PHP
<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Product;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;

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
        if (!is_numeric(\$id)) return response()->json(['message' => 'Invalid ID'], 404);

        \$product = Product::with(['category', 'brand', 'origin', 'unit'])->find(\$id);
        if (!\$product) return response()->json(['message' => 'Not found'], 404);
        
        return response()->json(['status' => 200, 'data' => \$product]);
    }

    public function store(Request \$request)
    {
        try {
            \$data = \$this->sanitizeData(\$request);
            
            // Validate SKU unique
            if (!empty(\$data['sku']) && Product::where('sku', \$data['sku'])->exists()) {
                return response()->json(['message' => 'SKU đã tồn tại'], 422);
            }

            if (empty(\$request->slug)) {
                \$data['slug'] = Str::slug(\$data['name']) . '-' . uniqid();
            }

            \$product = Product::create(\$data);
            return response()->json(['status' => 201, 'data' => \$product]);
        } catch (\Exception \$e) {
            Log::error('Product Store Error: ' . \$e->getMessage());
            return response()->json(['message' => 'Lỗi Server: ' . \$e->getMessage()], 500);
        }
    }

    public function update(Request \$request, \$id)
    {
        try {
            if (!is_numeric(\$id)) return response()->json(['message' => 'Invalid ID'], 404);
            
            \$product = Product::find(\$id);
            if (!\$product) return response()->json(['message' => 'Not found'], 404);

            \$data = \$this->sanitizeData(\$request);

            // Validate SKU unique (trừ chính nó ra)
            if (!empty(\$data['sku']) && Product::where('sku', \$data['sku'])->where('id', '!=', \$id)->exists()) {
                return response()->json(['message' => 'SKU đã tồn tại ở sản phẩm khác'], 422);
            }

            \$product->update(\$data);
            return response()->json(['status' => 200, 'data' => \$product]);

        } catch (\Exception \$e) {
            Log::error('Product Update Error: ' . \$e->getMessage());
            return response()->json(['message' => 'Lỗi Server: ' . \$e->getMessage()], 500);
        }
    }

    public function destroy(\$id)
    {
        if (!is_numeric(\$id)) return response()->json(['message' => 'Invalid ID'], 404);
        Product::destroy(\$id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }

    // Hàm dọn dẹp dữ liệu để tránh lỗi Foreign Key
    private function sanitizeData(Request \$request)
    {
        \$data = \$request->all();

        // Danh sách các trường khóa ngoại
        \$foreignKeys = ['category_id', 'brand_id', 'origin_id', 'unit_id'];

        foreach (\$foreignKeys as \$key) {
            // Nếu gửi lên là 0, "0", hoặc rỗng -> Chuyển thành NULL
            if (isset(\$data[\$key]) && (empty(\$data[\$key]) || \$data[\$key] === 0 || \$data[\$key] === '0')) {
                \$data[\$key] = null;
            }
        }

        // Xử lý ảnh
        if (\$request->has('images')) {
            \$images = \$request->input('images');
            if (!empty(\$images) && is_array(\$images)) {
                // Lọc bỏ ảnh rỗng
                \$data['images'] = array_values(array_filter(\$images, function(\$url) {
                    return !empty(\$url); 
                }));
                \$data['thumbnail'] = \$data['images'][0] ?? null;
            }
        }
        
        // Đảm bảo skin_type_ids là mảng (tránh lỗi JSON)
        if (isset(\$data['skin_type_ids']) && !is_array(\$data['skin_type_ids'])) {
             \$data['skin_type_ids'] = [];
        }

        return \$data;
    }
}
PHP

# Reload PHP-FPM để áp dụng code mới
sudo service php8.2-fpm reload 2>/dev/null || sudo service php8.3-fpm reload 2>/dev/null

echo "--------------------------------------------------------"
echo "✅ ĐÃ SỬA LỖI BACKEND THÀNH CÔNG!"
echo "👉 Hãy thử nhấn Lưu lại. Nếu vẫn lỗi, nó sẽ hiện thông báo chi tiết thay vì 500."
echo "--------------------------------------------------------"
