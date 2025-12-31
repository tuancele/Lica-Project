<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('coupons', function (Blueprint $table) {
            if (!Schema::hasColumn('coupons', 'is_public')) {
                $table->boolean('is_public')->default(true)->after('is_active'); // True: Hiện list, False: Chỉ nhập tay
            }
            if (!Schema::hasColumn('coupons', 'max_discount_amount')) {
                $table->decimal('max_discount_amount', 15, 2)->nullable()->after('value'); // Giảm tối đa (cho %)
            }
        });
    }

    public function down(): void
    {
        Schema::table('coupons', function (Blueprint $table) {
            $table->dropColumn(['is_public', 'max_discount_amount']);
        });
    }
};
