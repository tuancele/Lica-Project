<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Cho phép email null (để đăng ký bằng SĐT)
            $table->string('email')->nullable()->change();
            // Đảm bảo name có thể null hoặc set default nếu cần (nhưng logic code sẽ tự fill)
            $table->string('name')->nullable()->change(); 
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('email')->nullable(false)->change();
        });
    }
};
