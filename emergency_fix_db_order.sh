#!/bin/bash

echo "🚑 Đang sửa lỗi Database (Thiếu cột user_id trong bảng Orders)..."

cd /var/www/lica-project/backend

# ==============================================================================
# 1. TẠO MIGRATION SỬA LỖI (Đảm bảo chạy cuối cùng)
# ==============================================================================
echo "📝 Tạo file Migration sửa bảng Orders..."

# Đặt timestamp hiện tại để đảm bảo nó chạy sau cùng
TIMESTAMP=$(date +"%Y_%m_%d_%H%M%S")

cat << EOF > database/migrations/${TIMESTAMP}_fix_orders_table_missing_columns.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('orders', function (Blueprint \$table) {
            // 1. Kiểm tra và thêm user_id nếu thiếu
            if (!Schema::hasColumn('orders', 'user_id')) {
                \$table->foreignId('user_id')->nullable()->after('id')->constrained('users')->onDelete('set null');
            }

            // 2. Kiểm tra các cột quan trọng khác
            if (!Schema::hasColumn('orders', 'payment_status')) {
                \$table->string('payment_status')->default('pending');
            }
            
            if (!Schema::hasColumn('orders', 'shipping_fee')) {
                \$table->decimal('shipping_fee', 15, 2)->default(0);
            }
        });
    }

    public function down(): void
    {
        // Không làm gì để tránh mất dữ liệu
    }
};
EOF

# ==============================================================================
# 2. CHẠY MIGRATION
# ==============================================================================
echo "🔄 Chạy Migration..."
php artisan migrate --force

# ==============================================================================
# 3. DEBUG: KIỂM TRA LẠI CẤU TRÚC BẢNG
# ==============================================================================
echo "🔎 Kiểm tra cấu trúc bảng 'orders'..."
php artisan tinker --execute="print_r(Schema::getColumnListing('orders'));"

# ==============================================================================
# 4. CLEAR CACHE
# ==============================================================================
echo "🧹 Clear Cache..."
php artisan cache:clear
php artisan config:clear

echo "✅ Đã sửa xong Database! Hãy thử Đặt hàng lại."
