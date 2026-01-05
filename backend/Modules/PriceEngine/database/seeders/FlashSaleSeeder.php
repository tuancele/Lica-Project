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
