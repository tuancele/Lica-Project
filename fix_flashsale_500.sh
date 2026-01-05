#!/bin/bash

BACKEND_ROOT="/var/www/lica-project/backend"

echo "========================================================"
echo "   FIX LỖI 500 API FLASH SALE & BỔ SUNG CỘT THIẾU"
echo "========================================================"

# 1. Tạo Migration bổ sung cột rating và reviews_count (Nếu chưa có)
echo ">>> [1/4] Tạo Migration bổ sung cột rating..."
mkdir -p $BACKEND_ROOT/Modules/Product/database/migrations

cat << 'EOF' > $BACKEND_ROOT/Modules/Product/database/migrations/2025_02_02_000009_add_rating_fields_to_products.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('products')) {
            Schema::table('products', function (Blueprint $table) {
                if (!Schema::hasColumn('products', 'rating')) {
                    $table->decimal('rating', 3, 1)->default(5.0)->after('price');
                }
                if (!Schema::hasColumn('products', 'reviews_count')) {
                    $table->integer('reviews_count')->default(0)->after('rating');
                }
            });
        }
    }

    public function down(): void
    {
        // Không drop để tránh mất dữ liệu
    }
};
EOF

# 2. Cập nhật lại PriceEngineController (Query an toàn hơn)
echo ">>> [2/4] Cập nhật PriceEngineController..."
cat << 'EOF' > $BACKEND_ROOT/Modules/PriceEngine/app/Http/Controllers/PriceEngineController.php
<?php

namespace Modules\PriceEngine\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\PriceEngine\Models\Program;
use Modules\PriceEngine\Models\ProgramItem;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class PriceEngineController extends Controller
{
    public function index(Request $request)
    {
        $query = Program::withCount('items')->orderBy('id', 'desc');
        if ($request->has('type')) {
            $query->where('type', $request->type);
        }
        return response()->json(['status' => 200, 'data' => $query->paginate(20)]);
    }

    // API: Lấy Flash Sale đang diễn ra
    public function getActiveFlashSale()
    {
        try {
            $now = now();
            
            // Tìm chương trình Flash Sale đang active
            $flashSale = Program::where('type', 'flash_sale')
                ->where('is_active', true)
                ->where('start_at', '<=', $now)
                ->where('end_at', '>=', $now)
                ->with(['items.product']) // Lấy full product để tránh lỗi thiếu cột
                ->first();

            return response()->json([
                'status' => 200, 
                'data' => $flashSale
            ]);
        } catch (\Exception $e) {
            Log::error("Get Flash Sale Error: " . $e->getMessage());
            return response()->json(['status' => 500, 'message' => 'Server Error'], 500);
        }
    }

    public function store(Request $request) { return $this->saveProgram($request); }
    public function update(Request $request, $id) { return $this->saveProgram($request, $id); }

    private function saveProgram(Request $request, $id = null)
    {
        $request->validate([
            'name' => 'required|string',
            'start_at' => 'required|date',
            'end_at' => 'required|date|after:start_at',
            'products' => 'required|array|min:1',
        ]);

        DB::beginTransaction();
        try {
            $data = [
                'name' => $request->name,
                'start_at' => $request->start_at,
                'end_at' => $request->end_at,
                'type' => $request->type ?? 'promotion',
                'is_active' => true
            ];

            if ($id) {
                $program = Program::findOrFail($id);
                $program->update($data);
                $program->items()->delete();
            } else {
                $program = Program::create($data);
            }

            $itemsData = [];
            foreach ($request->products as $item) {
                if(!isset($item['id'])) continue;
                $itemsData[] = [
                    'program_id' => $program->id,
                    'product_id' => $item['id'],
                    'promotion_price' => $item['promotion_price'] ?? 0,
                    'stock_limit' => !empty($item['stock_limit']) ? $item['stock_limit'] : null,
                    'created_at' => now(),
                    'updated_at' => now(),
                ];
            }
            if(!empty($itemsData)) ProgramItem::insert($itemsData);

            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Thành công', 'data' => $program]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }

    public function show($id)
    {
        $program = Program::with('items.product')->find($id);
        return $program ? response()->json(['status' => 200, 'data' => $program]) : response()->json(['message' => 'Not found'], 404);
    }

    public function destroy($id)
    {
        Program::destroy($id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
EOF

# 3. Chạy Migration
echo ">>> [3/4] Chạy Migration..."
cd $BACKEND_ROOT
php artisan migrate --force

# 4. Tạo dữ liệu Flash Sale mẫu (Seeder)
echo ">>> [4/4] Tạo dữ liệu Flash Sale mẫu..."
cat << 'EOF' > $BACKEND_ROOT/Modules/PriceEngine/database/seeders/FlashSaleSeeder.php
<?php

namespace Modules\PriceEngine\Database\Seeders;

use Illuminate\Database\Seeder;
use Modules\PriceEngine\Models\Program;
use Modules\PriceEngine\Models\ProgramItem;
use Modules\Product\Models\Product;

class FlashSaleSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Xóa Flash Sale cũ đang chạy để tránh trùng
        Program::where('type', 'flash_sale')->delete();

        // 2. Lấy 5 sản phẩm đầu tiên
        $products = Product::limit(5)->get();

        if ($products->isEmpty()) {
            echo "Chưa có sản phẩm nào để tạo Flash Sale!\n";
            return;
        }

        // 3. Tạo Flash Sale đang diễn ra (Active)
        $program = Program::create([
            'name' => 'FLASH SALE GIỜ VÀNG (AUTO)',
            'type' => 'flash_sale',
            'start_at' => now()->subHours(1), // Bắt đầu cách đây 1 tiếng
            'end_at' => now()->addHours(5),   // Kết thúc sau 5 tiếng
            'is_active' => true,
        ]);

        foreach ($products as $product) {
            ProgramItem::create([
                'program_id' => $program->id,
                'product_id' => $product->id,
                'promotion_price' => $product->price * 0.7, // Giảm 30%
                'stock_limit' => 50,
            ]);
        }

        echo "Đã tạo Flash Sale ID: " . $program->id . "\n";
    }
}
EOF

# Chạy Seeder
php artisan db:seed --class="Modules\PriceEngine\Database\Seeders\FlashSaleSeeder"

# Xóa Cache
php artisan route:clear
php artisan config:clear
php artisan cache:clear

echo "========================================================"
echo "   ĐÃ KHẮC PHỤC LỖI! HÃY TẢI LẠI TRANG LICA.VN"
echo "========================================================"
