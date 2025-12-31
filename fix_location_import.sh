#!/bin/bash

echo "🛠️ Đang cập nhật Seeder Hành chính Việt Nam (Smart Import)..."

# ==============================================================================
# 1. CẬP NHẬT SEEDER (Hỗ trợ đa định dạng Key)
# ==============================================================================
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
        // Sử dụng nguồn dữ liệu ổn định từ 'madnh' (cấu trúc chuẩn hơn) nếu kenzouno1 lỗi
        // Hoặc vẫn dùng kenzouno1 nhưng handle key linh hoạt
        $url = 'https://raw.githubusercontent.com/kenzouno1/DiaGioiHanhChinhVN/master/data.json';
        
        $this->command->info("Downloading data from GitHub: $url");
        try {
            $jsonData = Http::timeout(60)->get($url)->json();
        } catch (\Exception $e) {
            $this->command->error("Download failed: " . $e->getMessage());
            return;
        }

        if (empty($jsonData) || !is_array($jsonData)) {
            $this->command->error("Data invalid or empty.");
            return;
        }

        $this->command->info("Starting Import... (Total: " . count($jsonData) . " provinces)");
        
        DB::beginTransaction();
        try {
            foreach ($jsonData as $prov) {
                // 1. Nhận diện Key (Id/id/code, Name/name, ...)
                $pId = $prov['Id'] ?? $prov['id'] ?? $prov['code'] ?? null;
                $pName = $prov['Name'] ?? $prov['name'] ?? null;
                
                if (!$pId || !$pName) {
                    $this->command->warn("Skipping invalid province data.");
                    continue;
                }

                // Insert Province
                DB::table('provinces')->updateOrInsert(
                    ['code' => $pId],
                    [
                        'name' => $pName,
                        'type' => $prov['Type'] ?? $prov['type'] ?? 'Tỉnh/Thành phố',
                        'slug' => Str::slug($pName),
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]
                );

                // Check Districts key
                $districts = $prov['Districts'] ?? $prov['districts'] ?? [];
                
                foreach ($districts as $dist) {
                    $dId = $dist['Id'] ?? $dist['id'] ?? $dist['code'] ?? null;
                    $dName = $dist['Name'] ?? $dist['name'] ?? null;

                    if (!$dId || !$dName) continue;

                    // Insert District
                    DB::table('districts')->updateOrInsert(
                        ['code' => $dId],
                        [
                            'province_code' => $pId,
                            'name' => $dName,
                            'type' => $dist['Type'] ?? $dist['type'] ?? 'Quận/Huyện',
                            'slug' => Str::slug($dName),
                            'created_at' => now(),
                            'updated_at' => now(),
                        ]
                    );

                    // Check Wards key
                    $wards = $dist['Wards'] ?? $dist['wards'] ?? [];
                    $wardsData = [];

                    foreach ($wards as $ward) {
                        $wId = $ward['Id'] ?? $ward['id'] ?? $ward['code'] ?? null;
                        $wName = $ward['Name'] ?? $ward['name'] ?? null;

                        if (!$wId || !$wName) continue;

                        $wardsData[] = [
                            'code' => $wId,
                            'district_code' => $dId,
                            'name' => $wName,
                            'type' => $ward['Type'] ?? $ward['type'] ?? 'Xã/Phường',
                            'slug' => Str::slug($wName),
                            'created_at' => now(),
                            'updated_at' => now(),
                        ];
                    }

                    // Bulk Insert Wards (chia nhỏ batch để tránh lỗi memory nếu quá nhiều)
                    if (!empty($wardsData)) {
                        foreach (array_chunk($wardsData, 500) as $chunk) {
                            DB::table('wards')->upsert($chunk, ['code'], ['name', 'district_code', 'type', 'slug', 'updated_at']);
                        }
                    }
                }
            }
            DB::commit();
            $this->command->info("✅ Import successful! Database is ready.");
        } catch (\Exception $e) {
            DB::rollBack();
            $this->command->error("Import Error: " . $e->getMessage());
        }
    }
}
EOF

# ==============================================================================
# 2. CHẠY LẠI IMPORT
# ==============================================================================
echo "🔄 Đang chạy lại Seeder..."
cd /var/www/lica-project/backend

# Dump autoload để đảm bảo class được nhận diện
composer dump-autoload

# Chạy seed
php artisan db:seed --class="Modules\\IAM\\Database\\Seeders\\VietnamLocationsSeeder"

echo "✅ Hoàn tất sửa lỗi!"
