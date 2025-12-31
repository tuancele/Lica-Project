<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('products', function (Blueprint $table) {
            // 1. Định danh cơ bản
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->string('sku')->unique()->nullable(); // Mã kho
            $table->string('brand')->nullable(); 
            $table->string('category')->nullable();

            // 2. Giá & Kho
            $table->decimal('price', 15, 2); // Giá niêm yết
            $table->decimal('sale_price', 15, 2)->nullable(); // Giá bán thực tế
            $table->integer('stock_quantity')->default(0);
            
            // 3. Thông số Vận chuyển (QUAN TRỌNG CHO GHTK/GRAB)
            $table->integer('weight')->default(0); // Gram
            $table->integer('length')->default(0); // Cm
            $table->integer('width')->default(0);  // Cm
            $table->integer('height')->default(0); // Cm

            // 4. Thông tin chi tiết Mỹ phẩm
            $table->text('short_description')->nullable();
            $table->longText('description')->nullable(); // HTML
            $table->longText('ingredients')->nullable(); // Thành phần
            $table->text('usage_instructions')->nullable(); // HDSD
            $table->string('skin_type')->nullable(); // Loại da
            $table->string('capacity')->nullable(); // Dung tích (50ml)

            // 5. Media (Max 9 ảnh)
            // thumbnail: Cache ảnh đầu tiên để query danh sách nhanh hơn
            $table->string('thumbnail')->nullable(); 
            // images: Chứa toàn bộ mảng ảnh (bao gồm cả ảnh đầu)
            $table->json('images')->nullable(); 

            // 6. Trạng thái
            $table->boolean('is_active')->default(true);
            $table->boolean('is_featured')->default(false);

            $table->timestamps();
        });
    }

    public function down(): void {
        Schema::dropIfExists('products');
    }
};
