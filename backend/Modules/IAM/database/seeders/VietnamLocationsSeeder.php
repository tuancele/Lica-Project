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
