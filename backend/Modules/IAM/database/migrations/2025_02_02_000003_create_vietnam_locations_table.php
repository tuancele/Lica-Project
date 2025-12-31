<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('provinces')) {
            Schema::create('provinces', function (Blueprint $table) {
                $table->string('code')->primary(); // Mã GSO (01, 79...)
                $table->string('name');
                $table->string('type')->nullable(); // Tỉnh / Thành phố TW
                $table->string('slug')->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('districts')) {
            Schema::create('districts', function (Blueprint $table) {
                $table->string('code')->primary();
                $table->string('province_code')->index();
                $table->string('name');
                $table->string('type')->nullable();
                $table->string('slug')->nullable();
                $table->foreign('province_code')->references('code')->on('provinces')->onDelete('cascade');
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('wards')) {
            Schema::create('wards', function (Blueprint $table) {
                $table->string('code')->primary();
                $table->string('district_code')->index();
                $table->string('name');
                $table->string('type')->nullable();
                $table->string('slug')->nullable();
                $table->foreign('district_code')->references('code')->on('districts')->onDelete('cascade');
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('wards');
        Schema::dropIfExists('districts');
        Schema::dropIfExists('provinces');
    }
};
