<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('products')) {
            Schema::table('products', function (Blueprint $table) {
                if (!Schema::hasColumn('products', 'rating')) {
                    $table->decimal('rating', 3, 1)->default(5.0)->after('price');
                }
                if (!Schema::hasColumn('products', 'reviews_count')) {
                    $table->integer('reviews_count')->default(0)->after('rating');
                }
            });
        }
    }

    public function down(): void
    {
        // Không drop để tránh mất dữ liệu
    }
};
