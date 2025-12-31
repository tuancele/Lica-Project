<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Bảng Mã giảm giá
        if (!Schema::hasTable('coupons')) {
            Schema::create('coupons', function (Blueprint $table) {
                $table->id();
                $table->string('code')->unique(); // Mã: SALE50
                $table->string('name'); // Tên: Giảm giá 50k
                $table->string('type')->default('fixed'); // fixed (tiền) hoặc percent (%)
                $table->decimal('value', 15, 2); // Giá trị giảm
                $table->decimal('min_order_value', 15, 2)->default(0); // Đơn tối thiểu
                $table->integer('usage_limit')->default(0); // Giới hạn số lượng
                $table->integer('used_count')->default(0); // Đã dùng
                $table->timestamp('start_date')->nullable();
                $table->timestamp('end_date')->nullable();
                $table->boolean('is_active')->default(true);
                $table->string('apply_type')->default('all'); // all (toàn shop) hoặc specific (sản phẩm cụ thể)
                $table->timestamps();
            });
        }

        // Bảng trung gian: Mã giảm giá áp dụng cho Sản phẩm nào
        if (!Schema::hasTable('coupon_product')) {
            Schema::create('coupon_product', function (Blueprint $table) {
                $table->id();
                $table->foreignId('coupon_id')->constrained()->onDelete('cascade');
                $table->foreignId('product_id')->constrained()->onDelete('cascade');
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('coupon_product');
        Schema::dropIfExists('coupons');
    }
};
