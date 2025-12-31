#!/bin/bash

echo "🛠️ Đang sửa lỗi cấu trúc bảng Products (Cho phép NULL Dimensions)..."

cd /var/www/lica-project/backend

# ==============================================================================
# 1. TẠO MIGRATION SỬA BẢNG PRODUCTS
# ==============================================================================
echo "📝 Tạo Migration..."
TIMESTAMP=$(date +"%Y_%m_%d_%H%M%S")

cat << EOF > Modules/Product/database/migrations/${TIMESTAMP}_make_product_dimensions_nullable.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint \$table) {
            // Cho phép các trường kích thước, cân nặng null
            // Dùng ->change() để sửa cột đã tồn tại
            if (Schema::hasColumn('products', 'weight')) {
                \$table->decimal('weight', 10, 2)->nullable()->change();
            }
            if (Schema::hasColumn('products', 'length')) {
                \$table->decimal('length', 10, 2)->nullable()->change();
            }
            if (Schema::hasColumn('products', 'width')) {
                \$table->decimal('width', 10, 2)->nullable()->change();
            }
            if (Schema::hasColumn('products', 'height')) {
                \$table->decimal('height', 10, 2)->nullable()->change();
            }
        });
    }

    public function down(): void
    {
        // Revert lại (nếu cần)
    }
};
EOF

# ==============================================================================
# 2. CHẠY MIGRATION
# ==============================================================================
echo "🔄 Chạy Migration..."
# Cần cài đặt doctrine/dbal để dùng hàm change()
composer require doctrine/dbal

php artisan migrate --force

# ==============================================================================
# 3. CLEAR CACHE
# ==============================================================================
echo "🧹 Clear Cache..."
php artisan cache:clear

echo "✅ Đã sửa xong! Bạn có thể lưu sản phẩm mà không cần nhập kích thước/cân nặng."
