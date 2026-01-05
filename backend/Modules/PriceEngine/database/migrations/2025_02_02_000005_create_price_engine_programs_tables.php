<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Bảng chương trình giảm giá (VD: Sale 9.9, Flash Sale)
        if (!Schema::hasTable('price_engine_programs')) {
            Schema::create('price_engine_programs', function (Blueprint $table) {
                $table->id();
                $table->string('name'); // Tên chương trình
                $table->dateTime('start_at'); // Thời gian bắt đầu
                $table->dateTime('end_at');   // Thời gian kết thúc
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        // 2. Bảng chi tiết sản phẩm trong chương trình
        if (!Schema::hasTable('price_engine_items')) {
            Schema::create('price_engine_items', function (Blueprint $table) {
                $table->id();
                $table->foreignId('program_id')->constrained('price_engine_programs')->onDelete('cascade');
                $table->unsignedBigInteger('product_id'); // Link tới bảng products
                $table->decimal('promotion_price', 15, 2); // Giá sau giảm (VD: 230.000)
                $table->integer('stock_limit')->nullable(); // Giới hạn số lượng bán (Option giống Shopee)
                $table->timestamps();

                // Index để query giá nhanh hơn khi load trang danh sách sản phẩm
                $table->index(['product_id', 'program_id']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('price_engine_items');
        Schema::dropIfExists('price_engine_programs');
    }
};
