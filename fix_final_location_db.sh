#!/bin/bash

BACKEND_ROOT="/var/www/lica-project/backend"

echo "========================================================"
echo "   FIX FINAL: CLEAN UP DATABASE & RELOAD LOCATION"
echo "========================================================"

# 1. Tạo Seeder dọn dẹp DB (Xóa bảng cũ)
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
        // Vô hiệu hóa foreign key check để drop bảng an toàn
        if (DB::connection()->getDriverName() === 'pgsql') {
            DB::statement('SET session_replication_role = replica;');
        } else {
            DB::statement('SET FOREIGN_KEY_CHECKS=0;');
        }

        Schema::dropIfExists('wards');
        Schema::dropIfExists('districts');
        Schema::dropIfExists('provinces');
        
        // Xóa log migration cũ để chạy lại được
        DB::table('migrations')->where('migration', 'like', '%create_vietnam_locations_table%')->delete();

        if (DB::connection()->getDriverName() === 'pgsql') {
            DB::statement('SET session_replication_role = origin;');
        } else {
            DB::statement('SET FOREIGN_KEY_CHECKS=1;');
        }
        
        echo "Đã xóa bảng cũ thành công!\n";
    }
}
EOF

# 2. Cập nhật Seeder dữ liệu chính (VietnamLocationsSeeder)
# Đảm bảo logic insert đúng cột code_name
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
        // Clear data nếu bảng đã tồn tại (dự phòng)
        DB::table('wards')->truncate();
        DB::table('districts')->truncate();
        DB::table('provinces')->truncate();

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

# 3. Chạy quy trình làm sạch và nạp lại
echo ">>> [3/3] Chạy Clean & Migrate & Seed..."
cd $BACKEND_ROOT
composer dump-autoload

# Bước quan trọng: Chạy Clean Seeder trước
php artisan db:seed --class="Modules\IAM\Database\Seeders\CleanLocationSeeder" --force

# Chạy lại migration để tạo bảng mới (có cột code_name)
php artisan migrate --force

# Chạy seeder nạp dữ liệu
php artisan db:seed --class="Modules\IAM\Database\Seeders\VietnamLocationsSeeder" --force

# Xóa cache
php artisan cache:clear

echo "========================================================"
echo "   ĐÃ HOÀN TẤT! DỮ LIỆU ĐỊA CHÍNH ĐÃ ĐƯỢC PHỤC HỒI."
echo "   HÃY KIỂM TRA LẠI TRANG CHECKOUT (F5)."
echo "========================================================"
