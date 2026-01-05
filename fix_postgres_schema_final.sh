#!/bin/bash

BACKEND_ROOT="/var/www/lica-project/backend"

echo "========================================================"
echo "   FIX SCHEMA POSTGRESQL: DROP & RE-MIGRATE LOCATIONS"
echo "========================================================"

# 1. Drop bảng Location cũ (Nếu tồn tại) để tránh conflict migration
echo ">>> [1/4] Dropping old tables..."
cd $BACKEND_ROOT
# Sử dụng tinker để drop bảng an toàn
php artisan tinker <<EOF
use Illuminate\Support\Facades\Schema;
Schema::dropIfExists('wards');
Schema::dropIfExists('districts');
Schema::dropIfExists('provinces');
exit
EOF

# 2. Xóa bản ghi migration cũ trong bảng 'migrations'
# Để Laravel hiểu là migration này chưa chạy và chạy lại nó
php artisan tinker <<EOF
use Illuminate\Support\Facades\DB;
DB::table('migrations')->where('migration', 'like', '%create_vietnam_locations_table%')->delete();
exit
EOF

# 3. Đảm bảo file Migration có cột code_name (Ghi đè lại cho chắc chắn)
echo ">>> [2/4] Re-creating Migration file..."
cat << 'EOF' > $BACKEND_ROOT/Modules/IAM/database/migrations/2025_02_02_000003_create_vietnam_locations_table.php
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
                $table->string('code', 20)->primary();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('full_name');
                $table->string('full_name_en')->nullable();
                $table->string('code_name')->nullable()->index(); // Index cho search nhanh
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('districts')) {
            Schema::create('districts', function (Blueprint $table) {
                $table->string('code', 20)->primary();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('full_name');
                $table->string('full_name_en')->nullable();
                $table->string('code_name')->nullable()->index();
                $table->string('province_code', 20);
                $table->foreign('province_code')->references('code')->on('provinces')->onDelete('cascade');
                $table->timestamps();
                $table->index('province_code');
            });
        }

        if (!Schema::hasTable('wards')) {
            Schema::create('wards', function (Blueprint $table) {
                $table->string('code', 20)->primary();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('full_name');
                $table->string('full_name_en')->nullable();
                $table->string('code_name')->nullable()->index();
                $table->string('district_code', 20);
                $table->foreign('district_code')->references('code')->on('districts')->onDelete('cascade');
                $table->timestamps();
                $table->index('district_code');
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
EOF

# 4. Chạy lại Migration & Seeder
echo ">>> [3/4] Running Migration & Seeder..."
composer dump-autoload
php artisan migrate --force
php artisan db:seed --class="Modules\IAM\Database\Seeders\VietnamLocationsSeeder" --force

# 5. Clear Cache
echo ">>> [4/4] Clearing Cache..."
php artisan cache:clear
php artisan config:clear

echo "========================================================"
echo "   ĐÃ FIX SCHEMA XONG! KIỂM TRA LẠI WEBSITE."
echo "========================================================"
