<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Product;
use Illuminate\Support\Str;

class ProductController extends Controller
{
    public function index(Request $request)
    {
        $query = Product::with('category'); // Eager load category để lấy tên

        if ($request->has('q')) {
            $query->where('name', 'like', "%{$request->q}%")
                  ->orWhere('sku', 'like', "%{$request->q}%");
        }
        
        if ($request->has('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        return response()->json($query->orderBy('created_at', 'desc')->paginate(20));
    }

    public function show($id)
    {
        $product = Product::with('category')->find($id);
        if (!$product) {
             $product = Product::with('category')->where('slug', $id)->first();
        }
        
        if (!$product) return response()->json(['message' => 'Not found'], 404);
        return response()->json($product);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string|max:255',
            'price' => 'required|numeric|min:0',
            'sku' => 'nullable|string|unique:products,sku',
            'category_id' => 'nullable|exists:categories,id', // Validate ID danh mục
            'brand' => 'nullable|string',
            'images' => 'nullable|array|max:9',
            'stock_quantity' => 'integer|min:0',
            'weight' => 'nullable|integer',
            'length' => 'nullable|integer',
            'width' => 'nullable|integer',
            'height' => 'nullable|integer',
            'sale_price' => 'nullable|numeric',
            'description' => 'nullable|string',
            'short_description' => 'nullable|string',
            'ingredients' => 'nullable|string',
        ]);

        if (empty($request->slug)) {
            $data['slug'] = Str::slug($data['name']) . '-' . uniqid();
        }

        if (!empty($data['images']) && is_array($data['images'])) {
            $data['thumbnail'] = $data['images'][0] ?? null;
        }

        $product = Product::create($data);
        return response()->json($product, 201);
    }

    public function update(Request $request, $id)
    {
        $product = Product::find($id);
        if (!$product) return response()->json(['message' => 'Not found'], 404);

        $data = $request->validate([
            'name' => 'string|max:255',
            'category_id' => 'nullable|exists:categories,id',
            'sku' => 'nullable|string|unique:products,sku,' . $id,
        ]);

        if ($request->has('images')) {
            $images = $request->input('images');
            if (!empty($images) && is_array($images)) {
                $request->merge(['thumbnail' => $images[0] ?? null]);
            }
        }

        $product->update($request->all());
        return response()->json($product);
    }

    public function destroy($id)
    {
        $product = Product::find($id);
        if ($product) {
            $product->delete();
            return response()->json(['message' => 'Deleted successfully']);
        }
        return response()->json(['message' => 'Not found'], 404);
    }
}
