<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            // Cho phép các trường kích thước, cân nặng null
            // Dùng ->change() để sửa cột đã tồn tại
            if (Schema::hasColumn('products', 'weight')) {
                $table->decimal('weight', 10, 2)->nullable()->change();
            }
            if (Schema::hasColumn('products', 'length')) {
                $table->decimal('length', 10, 2)->nullable()->change();
            }
            if (Schema::hasColumn('products', 'width')) {
                $table->decimal('width', 10, 2)->nullable()->change();
            }
            if (Schema::hasColumn('products', 'height')) {
                $table->decimal('height', 10, 2)->nullable()->change();
            }
        });
    }

    public function down(): void
    {
        // Revert lại (nếu cần)
    }
};
