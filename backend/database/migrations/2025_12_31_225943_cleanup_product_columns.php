<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::table('products', function (Blueprint $table) {
            // Xóa các cột dạng string cũ gây lỗi "value too long"
            if (Schema::hasColumn('products', 'brand')) $table->dropColumn('brand');
            if (Schema::hasColumn('products', 'origin')) $table->dropColumn('origin');
            if (Schema::hasColumn('products', 'unit')) $table->dropColumn('unit');
            if (Schema::hasColumn('products', 'category')) $table->dropColumn('category');
        });
    }
    public function down(): void {}
};
