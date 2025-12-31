#!/bin/bash

echo "🚑 Đang khôi phục dữ liệu Sản phẩm mẫu (ID: 1)..."

cd /var/www/lica-project/backend

# ==============================================================================
# 1. TẠO SEEDER KHÔI PHỤC SẢN PHẨM
# ==============================================================================
echo "📝 Tạo Emergency Product Seeder..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/Product/database/seeders/EmergencyProductSeeder.php
<?php

namespace Modules\Product\Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class EmergencyProductSeeder extends Seeder
{
    public function run()
    {
        // Xóa dữ liệu cũ nếu có để tránh trùng lặp
        // DB::table('products')->truncate(); // Không truncate để giữ data khác nếu có

        // Chèn sản phẩm ID = 1 bắt buộc
        DB::table('products')->updateOrInsert(
            ['id' => 1], // Điều kiện tìm
            [
                'name' => 'Sản phẩm Demo (Lica)',
                'slug' => 'san-pham-demo-lica',
                'sku' => 'DEMO-001',
                'price' => 500000,
                'sale_price' => 450000,
                'stock_quantity' => 100, // Số lượng tồn kho > 0 để đặt hàng được
                'description' => 'Mô tả sản phẩm demo...',
                'short_description' => 'Sản phẩm mẫu khôi phục.',
                'thumbnail' => 'https://placehold.co/400', // Ảnh demo
                'status' => 'active', // Hoặc 'published' tùy enum của bạn
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );
        
        $this->command->info('✅ Đã khôi phục sản phẩm ID: 1');
    }
}
EOF

# ==============================================================================
# 2. ĐĂNG KÝ AUTOLOAD (Đề phòng chưa nhận namespace)
# ==============================================================================
echo "🔄 Cập nhật Composer Autoload..."
# Thêm map namespace thủ công nếu chưa có (an toàn)
php -r "
\$file = 'composer.json';
\$json = json_decode(file_get_contents(\$file), true);
\$json['autoload']['psr-4']['Modules\\\\Product\\\\Database\\\\Seeders\\\\'] = 'Modules/Product/database/seeders/';
file_put_contents(\$file, json_encode(\$json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
"
composer dump-autoload

# ==============================================================================
# 3. CHẠY SEEDER
# ==============================================================================
echo "🌱 Đang chạy Seeder..."
php artisan db:seed --class="Modules\\Product\\Database\\Seeders\\EmergencyProductSeeder" --force

# ==============================================================================
# 4. CLEAR CACHE
# ==============================================================================
echo "🧹 Xóa Cache..."
php artisan cache:clear

echo "✅ Hoàn tất! Hãy thử tải lại trang Admin và đặt hàng lại."
