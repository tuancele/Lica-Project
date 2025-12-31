<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Category;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    public function index(Request $request)
    {
        // Lấy tất cả danh mục
        $allCategories = Category::with('parent')->get();
        
        // Logic sắp xếp theo dạng cây (Recursive)
        $sorted = [];
        $this->buildTree($allCategories, null, 0, $sorted);

        return response()->json(['status' => 200, 'data' => $sorted]);
    }

    // Hàm đệ quy để sắp xếp: Cha -> các con của cha đó -> Cha tiếp theo
    private function buildTree($items, $parentId, $level, &$result) {
        foreach ($items as $item) {
            if ($item->parent_id == $parentId) {
                $item->level = $level;
                $result[] = $item;
                $this->buildTree($items, $item->id, $level + 1, $result);
            }
        }
    }

    public function store(Request $request) {
        $request->validate(['name' => 'required|string|max:255']);
        $slug = Str::slug($request->name);
        if (Category::where('slug', $slug)->exists()) $slug .= '-' . time();
        $category = Category::create(['name' => $request->name, 'slug' => $slug, 'parent_id' => $request->parent_id, 'description' => $request->description, 'image' => $request->image]);
        return response()->json(['status' => 201, 'data' => $category]);
    }

    public function update(Request $request, $id) {
        $category = Category::find($id);
        if (!$category) return response()->json(['message' => 'Not found'], 404);
        $data = $request->all();
        if ($request->has('name') && $request->name !== $category->name) $data['slug'] = Str::slug($request->name) . '-' . rand(10, 99);
        $category->update($data);
        return response()->json(['status' => 200, 'data' => $category]);
    }

    public function destroy($id) {
        Category::where('parent_id', $id)->update(['parent_id' => null]);
        Category::destroy($id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
