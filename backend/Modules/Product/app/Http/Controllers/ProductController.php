<?php
namespace Modules\Product\Http\Controllers;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Product;
use Illuminate\Support\Str;

class ProductController extends Controller {
    public function index() {
        return response()->json(Product::where('is_active', true)->orderBy('id', 'desc')->get());
    }

    public function store(Request $request) {
        $data = $request->validate([
            'name' => 'required|string',
            'price' => 'required|numeric',
            'stock' => 'integer'
        ]);
        $data['slug'] = Str::slug($data['name']) . '-' . time();
        $product = Product::create($data);
        return response()->json($product, 201);
    }
    
    public function seed() {
        if(Product::count() > 0) return response()->json(['message' => 'Data already exists']);
        Product::create(['name' => 'Kem Chống Nắng Lica', 'slug' => 'kcn-lica', 'price' => 250000, 'stock' => 100]);
        Product::create(['name' => 'Sữa Rửa Mặt Tinh Chất', 'slug' => 'srm-tinh-chat', 'price' => 180000, 'stock' => 50]);
        return response()->json(['message' => 'Seeded successfully']);
    }
}
