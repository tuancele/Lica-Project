<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('price_engine_programs') && !Schema::hasColumn('price_engine_programs', 'type')) {
            Schema::table('price_engine_programs', function (Blueprint $table) {
                // type: 'promotion' (thường) hoặc 'flash_sale'
                $table->string('type')->default('promotion')->after('name')->index(); 
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('price_engine_programs') && Schema::hasColumn('price_engine_programs', 'type')) {
            Schema::table('price_engine_programs', function (Blueprint $table) {
                $table->dropColumn('type');
            });
        }
    }
};
