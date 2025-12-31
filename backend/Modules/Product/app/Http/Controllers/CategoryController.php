<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Category;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    // 1. Lấy danh sách (Dạng phẳng hoặc cây)
    public function index(Request $request)
    {
        // Nếu muốn lấy dạng cây để hiển thị Menu
        if ($request->has('tree')) {
            return response()->json([
                'data' => Category::with('children.children')->whereNull('parent_id')->get()
            ]);
        }

        // Mặc định lấy danh sách phẳng để đổ vào Select Box (Kèm parent để biết cha con)
        $categories = Category::orderBy('name')->get();
        
        // Sắp xếp lại danh sách theo phân cấp cha-con để hiển thị Select đẹp hơn
        $sorted = $this->sortCategories($categories);
        
        return response()->json(['data' => $sorted]);
    }

    // Hàm đệ quy sắp xếp danh mục cho Select box
    private function sortCategories($categories, $parentId = null, $prefix = '') {
        $result = [];
        foreach ($categories as $cat) {
            if ($cat->parent_id == $parentId) {
                $cat->name_display = $prefix . $cat->name; // Tên hiển thị có thụt đầu dòng
                $result[] = $cat;
                $result = array_merge($result, $this->sortCategories($categories, $cat->id, $prefix . '-- '));
            }
        }
        return $result;
    }

    // 2. Tạo mới (API chuẩn)
    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => 'required|string',
            'parent_id' => 'nullable|exists:categories,id'
        ]);
        
        $data['slug'] = Str::slug($data['name']) . '-' . time();
        $data['level'] = $data['parent_id'] ? 1 : 0; // Logic đơn giản, nếu cần chính xác hơn thì query cha
        
        if ($data['parent_id']) {
            $parent = Category::find($data['parent_id']);
            $data['level'] = $parent->level + 1;
        }

        return response()->json(Category::create($data), 201);
    }

    // 3. API ĐẶC BIỆT: SETUP DATA HASAKI (Chạy 1 lần)
    public function setupHasaki()
    {
        // Xóa sạch cũ
        try {
            \DB::statement('SET FOREIGN_KEY_CHECKS=0;');
            Category::truncate();
            \DB::statement('SET FOREIGN_KEY_CHECKS=1;');
        } catch (\Exception $e) {}

        $data = [
            'Chăm Sóc Da Mặt' => [
                'Làm Sạch Da' => ['Tẩy Trang', 'Sữa Rửa Mặt', 'Tẩy Tế Bào Chết', 'Toner'],
                'Đặc Trị' => ['Serum', 'Trị Mụn', 'Mờ Thâm Nám', 'Retinol'],
                'Dưỡng Ẩm' => ['Xịt Khoáng', 'Lotion', 'Kem Dưỡng Ẩm', 'Dầu Dưỡng'],
                'Chống Nắng' => ['Da Dầu', 'Da Khô', 'Da Nhạy Cảm'],
                'Mặt Nạ' => ['Mặt Nạ Giấy', 'Mặt Nạ Đất Sét', 'Mặt Nạ Ngủ'],
            ],
            'Trang Điểm' => [
                'Mặt' => ['Kem Lót', 'Kem Nền', 'Phấn Phủ', 'Che Khuyết Điểm', 'Má Hồng'],
                'Môi' => ['Son Thỏi', 'Son Kem Lì', 'Son Bóng', 'Son Dưỡng'],
                'Mắt' => ['Kẻ Mắt', 'Kẻ Mày', 'Mascara', 'Phấn Mắt'],
            ],
            'Chăm Sóc Cơ Thể' => [
                'Tắm & Dưỡng' => ['Sữa Tắm', 'Dưỡng Thể', 'Tẩy Tế Bào Chết Body'],
                'Khử Mùi' => ['Lăn Khử Mùi', 'Xịt Khử Mùi'],
                'Tay & Chân' => ['Kem Tay', 'Dưỡng Móng'],
            ],
            'Chăm Sóc Tóc' => [
                'Làm Sạch' => ['Dầu Gội', 'Dầu Xả', 'Dầu Gội Khô'],
                'Dưỡng Tóc' => ['Kem Ủ', 'Serum Tóc', 'Tinh Dầu'],
            ],
            'Thực Phẩm Chức Năng' => [
                'Làm Đẹp' => ['Collagen', 'Trắng Da', 'Cấp Nước', 'Giảm Cân'],
                'Sức Khỏe' => ['Vitamin C', 'Vitamin E', 'Kẽm', 'Omega 3'],
            ]
        ];

        $count = 0;
        foreach ($data as $rootName => $groups) {
            $root = Category::create(['name' => $rootName, 'slug' => Str::slug($rootName), 'level' => 0]);
            $count++;
            foreach ($groups as $groupName => $items) {
                $group = Category::create(['name' => $groupName, 'slug' => Str::slug($groupName) . '-' . time(), 'parent_id' => $root->id, 'level' => 1]);
                $count++;
                foreach ($items as $item) {
                    Category::create(['name' => $item, 'slug' => Str::slug($item) . '-' . time(), 'parent_id' => $group->id, 'level' => 2]);
                    $count++;
                }
            }
        }

        return response()->json(['message' => "Da tao thanh cong $count danh muc!"]);
    }
}
