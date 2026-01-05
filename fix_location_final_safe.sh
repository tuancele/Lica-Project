#!/bin/bash

BACKEND_ROOT="/var/www/lica-project/backend"

echo "========================================================"
echo "   FIX FINAL SAFE: CLEAN UP DB WITHOUT SUPERUSER"
echo "========================================================"

# 1. Tạo CleanLocationSeeder (Phiên bản an toàn, không cần quyền root DB)
echo ">>> [1/3] Tạo CleanLocationSeeder..."
mkdir -p $BACKEND_ROOT/Modules/IAM/database/seeders

cat << 'EOF' > $BACKEND_ROOT/Modules/IAM/database/seeders/CleanLocationSeeder.php
<?php

namespace Modules\IAM\Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

class CleanLocationSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Xóa dữ liệu theo thứ tự ngược để tránh lỗi khóa ngoại
        // Wards phụ thuộc Districts -> Xóa Wards trước
        // Districts phụ thuộc Provinces -> Xóa Districts trước
        
        echo "Deleting old data...\n";
        
        if (Schema::hasTable('wards')) {
            DB::table('wards')->delete(); // Delete thay vì Truncate để an toàn hơn
        }
        
        if (Schema::hasTable('districts')) {
            DB::table('districts')->delete();
        }
        
        if (Schema::hasTable('provinces')) {
            DB::table('provinces')->delete();
        }

        // 2. Drop bảng luôn để tái tạo schema mới
        echo "Dropping tables...\n";
        Schema::disableForeignKeyConstraints(); // Thử tắt check (chỉ work trên 1 số driver)
        Schema::dropIfExists('wards');
        Schema::dropIfExists('districts');
        Schema::dropIfExists('provinces');
        Schema::enableForeignKeyConstraints();
        
        // 3. Xóa log migration cũ
        DB::table('migrations')->where('migration', 'like', '%create_vietnam_locations_table%')->delete();
        
        echo "Đã xóa bảng cũ thành công!\n";
    }
}
EOF

# 2. Cập nhật VietnamLocationsSeeder (Bỏ các lệnh SET session role gây lỗi)
echo ">>> [2/3] Cập nhật VietnamLocationsSeeder..."
cat << 'EOF' > $BACKEND_ROOT/Modules/IAM/database/seeders/VietnamLocationsSeeder.php
<?php

namespace Modules\IAM\Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class VietnamLocationsSeeder extends Seeder
{
    public function run(): void
    {
        // Không cần truncate ở đây nữa vì CleanLocationSeeder đã làm rồi
        // Hoặc bảng mới tạo thì auto rỗng

        echo "Đang tải dữ liệu...\n";
        $json = file_get_contents('https://raw.githubusercontent.com/madnh/hanhchinhvn/master/dist/tree.json');
        $data = json_decode($json, true);

        if (!$data) { echo "Lỗi JSON!\n"; return; }

        $provinces = [];
        $districts = [];
        $wards = [];

        foreach ($data as $p) {
            $provinces[] = [
                'code' => $p['code'],
                'name' => $p['name'],
                'name_en' => $p['slug'],
                'full_name' => $p['name_with_type'],
                'full_name_en' => $p['name_with_type'],
                'code_name' => $p['slug'],
                'created_at' => now(), 'updated_at' => now()
            ];

            foreach ($p['quan-huyen'] as $d) {
                $districts[] = [
                    'code' => $d['code'],
                    'name' => $d['name'],
                    'name_en' => $d['slug'],
                    'full_name' => $d['name_with_type'],
                    'full_name_en' => $d['name_with_type'],
                    'code_name' => $d['slug'],
                    'province_code' => $p['code'],
                    'created_at' => now(), 'updated_at' => now()
                ];

                foreach ($d['xa-phuong'] as $w) {
                    $wards[] = [
                        'code' => $w['code'],
                        'name' => $w['name'],
                        'name_en' => $w['slug'],
                        'full_name' => $w['name_with_type'],
                        'full_name_en' => $w['name_with_type'],
                        'code_name' => $w['slug'],
                        'district_code' => $d['code'],
                        'created_at' => now(), 'updated_at' => now()
                    ];
                }
            }
        }

        foreach (array_chunk($provinces, 100) as $chunk) DB::table('provinces')->insert($chunk);
        echo "Đã nạp " . count($provinces) . " Tỉnh/Thành\n";

        foreach (array_chunk($districts, 100) as $chunk) DB::table('districts')->insert($chunk);
        echo "Đã nạp " . count($districts) . " Quận/Huyện\n";

        foreach (array_chunk($wards, 200) as $chunk) DB::table('wards')->insert($chunk);
        echo "Đã nạp " . count($wards) . " Phường/Xã\n";
    }
}
EOF

# 3. Chạy quy trình
echo ">>> [3/3] Chạy Clean & Migrate & Seed..."
cd $BACKEND_ROOT
composer dump-autoload

# Chạy Clean trước
php artisan db:seed --class="Modules\IAM\Database\Seeders\CleanLocationSeeder" --force

# Chạy Migrate lại (Tạo bảng mới có đủ cột)
php artisan migrate --force

# Chạy Seed nạp dữ liệu
php artisan db:seed --class="Modules\IAM\Database\Seeders\VietnamLocationsSeeder" --force

# Xóa cache
php artisan cache:clear

echo "========================================================"
echo "   ĐÃ HOÀN TẤT! DỮ LIỆU ĐỊA CHÍNH ĐÃ ĐƯỢC PHỤC HỒI."
echo "   HÃY KIỂM TRA LẠI TRANG CHECKOUT (F5)."
echo "========================================================"
