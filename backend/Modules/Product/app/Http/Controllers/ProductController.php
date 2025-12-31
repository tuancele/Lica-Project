<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Product;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Validator;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $query = Product::with(['category', 'brand', 'origin', 'unit']);

        if ($request->has('q') && !empty($request->q)) {
            $q = $request->q;
            $query->where(function($sub) use ($q) {
                $sub->where('name', 'like', "%{$q}%")
                    ->orWhere('sku', 'like', "%{$q}%");
            });
        }

        $query->orderBy('created_at', 'desc');

        return response()->json([
            'status' => 200, 
            'data' => $query->paginate($request->get('limit', 20))
        ]);
    }

    public function show($id)
    {
        if (!is_numeric($id)) return response()->json(['message' => 'ID không hợp lệ'], 404);
        $product = Product::with(['category', 'brand', 'origin', 'unit'])->find($id);
        return $product 
            ? response()->json(['status' => 200, 'data' => $product]) 
            : response()->json(['message' => 'Không tìm thấy'], 404);
    }

    public function store(Request $request) { return $this->saveProduct($request); }

    public function update(Request $request, $id) { return $this->saveProduct($request, $id); }

    private function saveProduct(Request $request, $id = null)
    {
        try {
            $rules = [
                'name' => 'required|string|max:255',
                'category_id' => 'required|numeric',
                'price' => 'required|numeric|min:0',
                'sku' => 'nullable|string|max:50|unique:products,sku' . ($id ? ",$id" : ''),
                'stock_quantity' => 'nullable|integer|min:0',
            ];

            $validator = Validator::make($request->all(), $rules);

            if ($validator->fails()) {
                return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);
            }

            $input = $request->all();
            
            $columns = Schema::getColumnListing('products');
            $data = array_intersect_key($input, array_flip($columns));

            $numericFields = ['price', 'sale_price', 'stock_quantity', 'weight', 'length', 'width', 'height', 'category_id', 'brand_id', 'origin_id', 'unit_id'];
            foreach ($numericFields as $field) {
                if (array_key_exists($field, $data)) {
                    $val = $data[$field];
                    $data[$field] = (is_numeric($val) && $val > 0) ? (float)$val : null;
                }
            }

            if (empty($data['slug'])) {
                $data['slug'] = Str::slug($data['name']) . '-' . uniqid();
            }
            if (empty($data['sku'])) {
                $data['sku'] = 'SKU-' . strtoupper(Str::random(8));
            }

            if (isset($input['images']) && is_array($input['images'])) {
                $data['images'] = array_values(array_filter($input['images']));
                $data['thumbnail'] = $data['images'][0] ?? null;
            }
            if (isset($input['skin_type_ids'])) {
                $data['skin_type_ids'] = is_array($input['skin_type_ids']) ? array_map('intval', $input['skin_type_ids']) : [];
            }

            if ($id) {
                $product = Product::findOrFail($id);
                $product->update($data);
            } else {
                $product = Product::create($data);
            }

            return response()->json(['status' => 200, 'data' => $product, 'message' => 'Lưu thành công']);

        } catch (\Exception $e) {
            Log::error('Product Save Error: ' . $e->getMessage());
            return response()->json(['message' => 'Lỗi server: ' . $e->getMessage()], 500);
        }
    }

    public function destroy($id)
    {
        Product::destroy($id);
        return response()->json(['status' => 200, 'message' => 'Đã xóa sản phẩm']);
    }
}
