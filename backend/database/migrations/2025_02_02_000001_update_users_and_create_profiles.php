<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Update Users table
        if (Schema::hasTable('users')) {
            Schema::table('users', function (Blueprint $table) {
                if (!Schema::hasColumn('users', 'phone')) {
                    $table->string('phone')->nullable()->unique()->after('email');
                }
                if (!Schema::hasColumn('users', 'avatar')) {
                    $table->string('avatar')->nullable();
                }
                if (!Schema::hasColumn('users', 'username')) {
                    $table->string('username')->nullable()->unique(); // Cho URL /profile/tuancele
                }
                if (!Schema::hasColumn('users', 'membership_tier')) {
                    $table->string('membership_tier')->default('member'); // member, silver, gold, diamond
                }
                if (!Schema::hasColumn('users', 'points')) {
                    $table->integer('points')->default(0);
                }
            });
        }

        // 2. Add user_id to Orders
        if (Schema::hasTable('orders')) {
            Schema::table('orders', function (Blueprint $table) {
                if (!Schema::hasColumn('orders', 'user_id')) {
                    $table->foreignId('user_id')->nullable()->constrained('users')->onDelete('set null');
                }
            });
        }

        // 3. User Addresses (Sổ địa chỉ)
        if (!Schema::hasTable('user_addresses')) {
            Schema::create('user_addresses', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained()->onDelete('cascade');
                $table->string('name'); // Tên người nhận
                $table->string('phone');
                $table->text('address');
                $table->string('province_id')->nullable();
                $table->string('district_id')->nullable();
                $table->string('ward_id')->nullable();
                $table->boolean('is_default')->default(false);
                $table->timestamps();
            });
        }

        // 4. Wishlists (Sản phẩm yêu thích)
        if (!Schema::hasTable('wishlists')) {
            Schema::create('wishlists', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained()->onDelete('cascade');
                $table->foreignId('product_id')->constrained()->onDelete('cascade');
                $table->timestamps();
                $table->unique(['user_id', 'product_id']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('wishlists');
        Schema::dropIfExists('user_addresses');
    }
};
