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
