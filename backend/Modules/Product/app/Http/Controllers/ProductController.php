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
    public function index(Request $request)
    {
        $query = Product::with(['category', 'brand', 'origin', 'unit']);
        if ($request->has('q')) {
            $query->where('name', 'like', "%{$request->q}%")->orWhere('sku', 'like', "%{$request->q}%");
        }
        return response()->json(['status' => 200, 'data' => $query->orderBy('created_at', 'desc')->paginate(20)]);
    }

    public function show($id)
    {
        if (!is_numeric($id)) return response()->json(['message' => 'ID không hợp lệ'], 404);
        $product = Product::with(['category', 'brand', 'origin', 'unit'])->find($id);
        return $product ? response()->json(['status' => 200, 'data' => $product]) : response()->json(['message' => 'Không tìm thấy'], 404);
    }

    public function store(Request $request) { return $this->saveProduct($request); }

    public function update(Request $request, $id) { return $this->saveProduct($request, $id); }

    private function saveProduct(Request $request, $id = null)
    {
        try {
            $input = $request->all();
            
            // 1. Lọc dữ liệu: CHỈ giữ lại các cột có trong DB, bỏ qua các Object category/brand từ FE gửi lên
            $columns = Schema::getColumnListing('products');
            $data = array_intersect_key($input, array_flip($columns));

            // 2. Ép kiểu số & Xử lý null cho khóa ngoại
            $numericFields = ['price', 'sale_price', 'stock_quantity', 'weight', 'length', 'width', 'height', 'category_id', 'brand_id', 'origin_id', 'unit_id'];
            foreach ($numericFields as $field) {
                if (array_key_exists($field, $data)) {
                    $val = $data[$field];
                    $data[$field] = (is_numeric($val) && $val > 0) ? (float)$val : null;
                }
            }

            // 3. Xử lý Slug & SKU
            if (!$id) {
                if (empty($data['slug'])) $data['slug'] = Str::slug($data['name']) . '-' . uniqid();
                if (empty($data['sku'])) $data['sku'] = 'SKU-' . strtoupper(Str::random(6));
            }

            // 4. Xử lý Ảnh & JSON
            if (isset($input['images']) && is_array($input['images'])) {
                $data['images'] = array_values(array_filter($input['images']));
                $data['thumbnail'] = $data['images'][0] ?? null;
            }
            if (isset($input['skin_type_ids'])) {
                $data['skin_type_ids'] = is_array($input['skin_type_ids']) ? array_map('intval', $input['skin_type_ids']) : [];
            }

            // 5. Thực thi Lưu
            if ($id) {
                $product = Product::findOrFail($id);
                $product->update($data);
            } else {
                $product = Product::create($data);
            }

            return response()->json(['status' => 200, 'data' => $product]);

        } catch (\Exception $e) {
            Log::error('Product Save Error: ' . $e->getMessage());
            return response()->json(['message' => 'Lỗi: ' . $e->getMessage()], 500);
        }
    }

    public function destroy($id)
    {
        Product::destroy($id);
        return response()->json(['status' => 200, 'message' => 'Đã xóa']);
    }
}
