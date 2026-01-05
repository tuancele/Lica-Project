<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Bảng Chương trình khuyến mãi
        if (!Schema::hasTable('promotions')) {
            Schema::create('promotions', function (Blueprint $table) {
                $table->id();
                $table->string('name'); // Tên chương trình (VD: Sale Giáng Sinh)
                $table->timestamp('start_date');
                $table->timestamp('end_date');
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        // Bảng chi tiết sản phẩm trong chương trình
        if (!Schema::hasTable('promotion_product')) {
            Schema::create('promotion_product', function (Blueprint $table) {
                $table->id();
                $table->foreignId('promotion_id')->constrained()->onDelete('cascade');
                $table->foreignId('product_id')->constrained()->onDelete('cascade');
                $table->string('discount_type')->default('percent'); // percent (%) hoặc fixed (tiền)
                $table->decimal('discount_value', 15, 2); // Giá trị giảm
                $table->decimal('final_price', 15, 2); // Giá sau giảm (Lưu luôn để query cho nhanh)
                $table->integer('stock_limit')->default(0); // Giới hạn số lượng khuyến mãi (0 = không giới hạn)
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('promotion_product');
        Schema::dropIfExists('promotions');
    }
};
