#!/bin/bash

BACKEND_DIR="/var/www/lica-project/backend"
CTRL_FILE="$BACKEND_DIR/Modules/Product/app/Http/Controllers/ProductController.php"

echo ">>> ĐANG FIX LỖI SQL UNDEFINED COLUMN..."

cat > "$CTRL_FILE" <<PHP
<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Product;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;

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
            \$data = \$this->prepareData(\$request);
            if (empty(\$data['slug'])) \$data['slug'] = Str::slug(\$data['name']) . '-' . uniqid();
            
            if (!empty(\$data['sku']) && Product::where('sku', \$data['sku'])->exists()) {
                return response()->json(['message' => 'SKU đã tồn tại'], 422);
            }

            \$product = Product::create(\$data);
            return response()->json(['status' => 201, 'data' => \$product]);
        } catch (\Exception \$e) {
            Log::error('Store Error: '.\$e->getMessage());
            return response()->json(['message' => 'Lỗi: ' . \$e->getMessage()], 500);
        }
    }

    public function update(Request \$request, \$id)
    {
        try {
            \$product = Product::find(\$id);
            if (!\$product) return response()->json(['message' => 'Not found'], 404);

            \$data = \$this->prepareData(\$request);

            if (!empty(\$data['sku']) && Product::where('sku', \$data['sku'])->where('id', '!=', \$id)->exists()) {
                return response()->json(['message' => 'SKU đã trùng với sản phẩm khác'], 422);
            }

            // Dùng fill() và save() thay vì update() để tránh lỗi fillable nếu có
            \$product->fill(\$data);
            \$product->save();
            
            return response()->json(['status' => 200, 'data' => \$product]);

        } catch (\Exception \$e) {
            Log::error('Update Error: '.\$e->getMessage());
            return response()->json(['message' => 'Lỗi: ' . \$e->getMessage()], 500);
        }
    }

    public function destroy(\$id)
    {
        Product::destroy(\$id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }

    private function prepareData(Request \$request)
    {
        // 1. Lấy tất cả input
        \$input = \$request->all();
        
        // 2. Lấy danh sách các cột THỰC TẾ có trong bảng products
        \$columns = Schema::getColumnListing('products');
        
        // 3. Chỉ giữ lại những gì có trong DB (Loại bỏ object 'category', 'brand'...)
        \$data = array_intersect_key(\$input, array_flip(\$columns));

        // 4. Ép kiểu số cho an toàn
        \$numericFields = ['price', 'sale_price', 'stock_quantity', 'weight', 'length', 'width', 'height'];
        foreach (\$numericFields as \$field) {
            if (isset(\$data[\$field])) {
                \$data[\$field] = is_numeric(\$data[\$field]) ? (float)\$data[\$field] : 0;
            }
        }

        // 5. Khóa ngoại (Nếu 0 hoặc rỗng -> null)
        foreach (['category_id', 'brand_id', 'origin_id', 'unit_id'] as \$key) {
            if (isset(\$data[\$key]) && (empty(\$data[\$key]) || \$data[\$key] == 0)) {
                \$data[\$key] = null;
            }
        }

        // 6. Trường JSON
        if (\$request->has('skin_type_ids')) {
            \$data['skin_type_ids'] = is_array(\$input['skin_type_ids']) ? \$input['skin_type_ids'] : [];
        }

        // 7. Xử lý ảnh
        if (\$request->has('images')) {
            \$images = array_values(array_filter(\$input['images'], fn(\$v) => !empty(\$v)));
            \$data['images'] = \$images;
            \$data['thumbnail'] = \$images[0] ?? null;
        }

        return \$data;
    }
}
PHP

sudo service php8.3-fpm reload 2>/dev/null || sudo service php8.2-fpm reload 2>/dev/null

echo "✅ ĐÃ FIX LỖI SQL UNDEFINED COLUMN."
echo "👉 Bạn hãy thử nhấn Lưu lại ngay bây giờ."
