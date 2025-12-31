#!/bin/bash

echo "🛠️ Đang sửa lỗi Seeder Sản phẩm..."

cd /var/www/lica-project/backend

# ==============================================================================
# CẬP NHẬT SEEDER (Check cột trước khi insert)
# ==============================================================================
cat << 'EOF' > /var/www/lica-project/backend/Modules/Product/database/seeders/EmergencyProductSeeder.php
<?php

namespace Modules\Product\Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class EmergencyProductSeeder extends Seeder
{
    public function run()
    {
        // Dữ liệu cơ bản
        $data = [
            'name' => 'Sản phẩm Demo (Lica)',
            'slug' => 'san-pham-demo-lica',
            'sku' => 'DEMO-001',
            'price' => 500000,
            'sale_price' => 450000,
            'stock_quantity' => 100,
            'description' => 'Mô tả sản phẩm demo...',
            'short_description' => 'Sản phẩm mẫu khôi phục.',
            'thumbnail' => 'https://placehold.co/400',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ];

        // Kiểm tra nếu bảng products có cột 'status' thì mới thêm vào
        if (Schema::hasColumn('products', 'status')) {
            $data['status'] = 'active';
        }

        // Chèn dữ liệu
        DB::table('products')->updateOrInsert(
            ['id' => 1],
            $data
        );
        
        $this->command->info('✅ Đã khôi phục sản phẩm ID: 1 thành công!');
    }
}
EOF

# ==============================================================================
# CHẠY LẠI SEEDER
# ==============================================================================
echo "🔄 Cập nhật Autoload..."
composer dump-autoload

echo "🌱 Đang chạy lại Seeder..."
php artisan db:seed --class="Modules\\Product\\Database\\Seeders\\EmergencyProductSeeder" --force

echo "✅ Hoàn tất! Bạn có thể đặt hàng lại ngay."
