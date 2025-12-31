#!/bin/bash

echo "🛠️ Đang khắc phục lỗi thiếu dữ liệu Tỉnh/Thành..."

cd /var/www/lica-project/backend

# ==============================================================================
# 1. ĐẢM BẢO FILE SEEDER TỒN TẠI VÀ ĐÚNG NỘI DUNG
# ==============================================================================
echo "📝 Cập nhật lại Seeder (đảm bảo logic import đúng)..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/database/seeders/VietnamLocationsSeeder.php
<?php

namespace Modules\IAM\Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class VietnamLocationsSeeder extends Seeder
{
    public function run()
    {
        // URL dự phòng nếu link chính github bị lỗi
        $url = 'https://raw.githubusercontent.com/kenzouno1/DiaGioiHanhChinhVN/master/data.json';
        
        $this->command->info("Downloading data from: $url");
        
        try {
            $jsonData = Http::withoutVerifying()->timeout(120)->get($url)->json();
        } catch (\Exception $e) {
            $this->command->error("Download Failed: " . $e->getMessage());
            return;
        }

        if (empty($jsonData)) {
            $this->command->error("JSON Data is empty!");
            return;
        }

        $count = count($jsonData);
        $this->command->info("Found $count provinces. Importing...");

        DB::beginTransaction();
        try {
            foreach ($jsonData as $prov) {
                // Xử lý linh hoạt key Id/id/code
                $pId = $prov['Id'] ?? $prov['id'] ?? $prov['code'] ?? null;
                $pName = $prov['Name'] ?? $prov['name'] ?? null;
                
                if (!$pId) continue;

                // 1. Insert Tỉnh
                DB::table('provinces')->updateOrInsert(
                    ['code' => $pId],
                    [
                        'name' => $pName,
                        'type' => $prov['Type'] ?? 'Tỉnh/TP',
                        'slug' => Str::slug($pName),
                        'created_at' => now(), 
                        'updated_at' => now()
                    ]
                );

                $districts = $prov['Districts'] ?? $prov['districts'] ?? [];
                foreach ($districts as $dist) {
                    $dId = $dist['Id'] ?? $dist['id'] ?? $dist['code'] ?? null;
                    $dName = $dist['Name'] ?? $dist['name'] ?? null;
                    
                    if (!$dId) continue;

                    // 2. Insert Huyện
                    DB::table('districts')->updateOrInsert(
                        ['code' => $dId],
                        [
                            'province_code' => $pId,
                            'name' => $dName,
                            'type' => $dist['Type'] ?? 'Quận/Huyện',
                            'slug' => Str::slug($dName),
                            'created_at' => now(), 
                            'updated_at' => now()
                        ]
                    );

                    $wards = $dist['Wards'] ?? $dist['wards'] ?? [];
                    $wardsData = [];
                    foreach ($wards as $ward) {
                        $wId = $ward['Id'] ?? $ward['id'] ?? $ward['code'] ?? null;
                        $wName = $ward['Name'] ?? $ward['name'] ?? null;

                        if ($wId) {
                            $wardsData[] = [
                                'code' => $wId,
                                'district_code' => $dId,
                                'name' => $wName,
                                'type' => $ward['Type'] ?? 'Xã/Phường',
                                'slug' => Str::slug($wName),
                                'created_at' => now(),
                                'updated_at' => now()
                            ];
                        }
                    }
                    
                    // 3. Insert Xã (Batch Insert)
                    if (!empty($wardsData)) {
                        DB::table('wards')->upsert($wardsData, ['code'], ['name', 'district_code', 'updated_at']);
                    }
                }
            }
            DB::commit();
            $this->command->info("✅ Import Completed Successfully!");
        } catch (\Exception $e) {
            DB::rollBack();
            $this->command->error("Import Failed: " . $e->getMessage());
        }
    }
}
EOF

# ==============================================================================
# 2. CHẠY LẠI IMPORT & CLEAR CACHE
# ==============================================================================
echo "🔄 Cập nhật Autoload..."
composer dump-autoload

echo "🧹 Xóa dữ liệu cũ & Import lại..."
# Xóa bảng cũ để tránh conflict rác (nếu cần thiết, hoặc seed đè lên)
php artisan db:seed --class="Modules\\IAM\\Database\\Seeders\\VietnamLocationsSeeder" --force

echo "🧹 Xóa Cache ứng dụng..."
php artisan cache:clear
php artisan config:clear
php artisan route:clear

# ==============================================================================
# 3. KIỂM TRA KẾT QUẢ NGAY LẬP TỨC
# ==============================================================================
echo "🔎 Kiểm tra dữ liệu trong Database..."
PROVINCE_COUNT=$(php artisan tinker --execute="echo DB::table('provinces')->count();")
echo "--> Số lượng Tỉnh/Thành hiện có: $PROVINCE_COUNT"

echo "🔎 Test API lấy danh sách Tỉnh..."
curl -s "http://127.0.0.1/api/v1/location/provinces" -H "Host: api.lica.vn" | grep -o '"name":"[^"]*"' | head -n 3

echo ""
echo "✅ Quá trình khắc phục hoàn tất!"
