<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('slug')->unique();
            $table->unsignedBigInteger('parent_id')->nullable(); // Để tạo cây đa cấp
            $table->string('image')->nullable();
            $table->integer('level')->default(0); // 0: Root, 1: Sub, 2: Detail
            $table->boolean('is_active')->default(true);
            $table->timestamps();

            // Tự tham chiếu chính nó
            $table->foreign('parent_id')->references('id')->on('categories')->onDelete('cascade');
        });

        // Cập nhật bảng products: Xóa cột category string cũ, thêm category_id
        Schema::table('products', function (Blueprint $table) {
            if (Schema::hasColumn('products', 'category')) {
                $table->dropColumn('category');
            }
            $table->unsignedBigInteger('category_id')->nullable()->after('brand');
            $table->foreign('category_id')->references('id')->on('categories')->onDelete('set null');
        });
    }

    public function down(): void {
        Schema::table('products', function (Blueprint $table) {
            $table->dropForeign(['category_id']);
            $table->dropColumn('category_id');
            $table->string('category')->nullable();
        });
        Schema::dropIfExists('categories');
    }
};
