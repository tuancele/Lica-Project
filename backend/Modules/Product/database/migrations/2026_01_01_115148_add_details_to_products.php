<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            if (!Schema::hasColumn('products', 'brand')) $table->string('brand')->nullable();
            if (!Schema::hasColumn('products', 'origin')) $table->string('origin')->nullable();
            if (!Schema::hasColumn('products', 'capacity')) $table->string('capacity')->nullable(); // Dung tích (30ml)
            if (!Schema::hasColumn('products', 'ingredients')) $table->text('ingredients')->nullable();
            if (!Schema::hasColumn('products', 'usage_guide')) $table->text('usage_guide')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['brand', 'origin', 'capacity', 'ingredients', 'usage_guide']);
        });
    }
};
