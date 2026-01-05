#!/bin/bash

# Định nghĩa đường dẫn
BACKEND_ROOT="/var/www/lica-project/backend"

echo "========================================================"
echo "   CẬP NHẬT DỮ LIỆU ĐỊA CHÍNH VIỆT NAM (MỚI NHẤT)"
echo "   & SỬA LỖI 500 API LOCATION"
echo "========================================================"

# 1. Cập nhật LocationController (An toàn hơn, bỏ Cache tạm thời)
echo ">>> [1/4] Viết lại LocationController..."
cat << 'EOF' > $BACKEND_ROOT/Modules/IAM/app/Http/Controllers/LocationController.php
<?php

namespace Modules\IAM\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\IAM\Models\Province;
use Modules\IAM\Models\District;
use Modules\IAM\Models\Ward;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class LocationController extends Controller
{
    // Lấy danh sách Tỉnh/Thành
    public function getProvinces() {
        try {
            // Lấy trực tiếp từ DB, bỏ cache để tránh lỗi quyền
            $data = Province::select('code', 'name', 'full_name')->orderBy('code')->get();
            return response()->json(['status' => 200, 'data' => $data]);
        } catch (\Exception $e) {
            Log::error("Location Error (Provinces): " . $e->getMessage());
            return response()->json(['status' => 500, 'message' => 'Lỗi server: ' . $e->getMessage()], 500);
        }
    }

    // Lấy Quận/Huyện
    public function getDistricts($p) {
        try {
            $data = District::select('code', 'name', 'full_name')
                ->where('province_code', $p)
                ->orderBy('code')
                ->get();
            return response()->json(['status' => 200, 'data' => $data]);
        } catch (\Exception $e) {
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }

    // Lấy Phường/Xã
    public function getWards($d) {
        try {
            $data = Ward::select('code', 'name', 'full_name')
                ->where('district_code', $d)
                ->orderBy('code')
                ->get();
            return response()->json(['status' => 200, 'data' => $data]);
        } catch (\Exception $e) {
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }

    // Tìm kiếm thông minh (Smart Search)
    public function search(Request $request)
    {
        try {
            $q = trim($request->get('q'));
            if (!$q || strlen($q) < 2) return response()->json(['status' => 200, 'data' => []]);

            $slug = Str::slug($q, ' '); 

            $results = Ward::query()
                ->join('districts', 'wards.district_code', '=', 'districts.code')
                ->join('provinces', 'districts.province_code', '=', 'provinces.code')
                ->where(function($query) use ($q, $slug) {
                    $query->where('wards.name', 'LIKE', "%{$q}%")
                          ->orWhere('districts.name', 'LIKE', "%{$q}%")
                          ->orWhere('provinces.name', 'LIKE', "%{$q}%")
                          ->orWhere('wards.code_name', 'LIKE', "%{$slug}%")
                          ->orWhere('districts.code_name', 'LIKE', "%{$slug}%")
                          ->orWhere('provinces.code_name', 'LIKE', "%{$slug}%");
                })
                ->limit(20)
                ->select(
                    'wards.code as ward_code',
                    'wards.full_name as ward_name',
                    'districts.code as district_code',
                    'districts.full_name as district_name',
                    'provinces.code as province_code',
                    'provinces.full_name as province_name'
                )
                ->get();

            $data = $results->map(function($item) {
                return [
                    'label' => "{$item->ward_name}, {$item->district_name}, {$item->province_name}",
                    'province_code' => $item->province_code,
                    'district_code' => $item->district_code,
                    'ward_code' => $item->ward_code,
                    'province_name' => $item->province_name,
                    'district_name' => $item->district_name,
                    'ward_name' => $item->ward_name,
                ];
            });

            return response()->json(['status' => 200, 'data' => $data]);
        } catch (\Exception $e) {
            Log::error("Search Location Error: " . $e->getMessage());
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }
}
EOF

# 2. Cập nhật Seeder với nguồn dữ liệu JSON chuẩn nhất
echo ">>> [2/4] Tạo Seeder tải dữ liệu chuẩn..."
cat << 'EOF' > $BACKEND_ROOT/Modules/IAM/database/seeders/VietnamLocationsSeeder.php
<?php

namespace Modules\IAM\Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class VietnamLocationsSeeder extends Seeder
{
    public function run(): void
    {
        // Xóa dữ liệu cũ để nạp mới hoàn toàn
        DB::statement('SET FOREIGN_KEY_CHECKS=0;');
        DB::table('wards')->truncate();
        DB::table('districts')->truncate();
        DB::table('provinces')->truncate();
        DB::statement('SET FOREIGN_KEY_CHECKS=1;');

        echo "Đang tải dữ liệu địa chính mới nhất...\n";
        
        // Nguồn dữ liệu uy tín (madnh/hanhchinhvn)
        $json = file_get_contents('https://raw.githubusercontent.com/madnh/hanhchinhvn/master/dist/tree.json');
        $data = json_decode($json, true);

        if (!$data) {
            echo "Lỗi tải dữ liệu JSON!\n";
            return;
        }

        echo "Bắt đầu nạp dữ liệu...\n";
        
        $provinces = [];
        $districts = [];
        $wards = [];

        foreach ($data as $pCode => $p) {
            $provinces[] = [
                'code' => $p['code'],
                'name' => $p['name'],
                'name_en' => $p['slug'],
                'full_name' => $p['name_with_type'],
                'full_name_en' => $p['name_with_type'],
                'code_name' => $p['slug'],
                'created_at' => now(), 'updated_at' => now()
            ];

            foreach ($p['quan-huyen'] as $dCode => $d) {
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

                foreach ($d['xa-phuong'] as $wCode => $w) {
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

        // Chunk insert để tránh lỗi memory
        foreach (array_chunk($provinces, 100) as $chunk) DB::table('provinces')->insert($chunk);
        echo "- Đã nạp " . count($provinces) . " Tỉnh/Thành\n";

        foreach (array_chunk($districts, 100) as $chunk) DB::table('districts')->insert($chunk);
        echo "- Đã nạp " . count($districts) . " Quận/Huyện\n";

        foreach (array_chunk($wards, 200) as $chunk) DB::table('wards')->insert($chunk);
        echo "- Đã nạp " . count($wards) . " Phường/Xã\n";
    }
}
EOF

# 3. Chạy Migration & Seeder
echo ">>> [3/4] Reset DB & Seed dữ liệu..."
cd $BACKEND_ROOT

# Update autoload
composer dump-autoload

# Chạy migration để đảm bảo bảng tồn tại
php artisan migrate --force

# Chạy seeder
php artisan db:seed --class="Modules\IAM\Database\Seeders\VietnamLocationsSeeder" --force

# 4. Xóa cache hệ thống
echo ">>> [4/4] Xóa cache..."
php artisan route:clear
php artisan config:clear
php artisan cache:clear

# Cấp quyền lại cho thư mục storage (quan trọng)
chown -R www-data:www-data storage
chmod -R 775 storage

echo "========================================================"
echo "   HOÀN TẤT! DỮ LIỆU ĐÃ ĐƯỢC CẬP NHẬT."
echo "   HÃY TẢI LẠI TRANG CHECKOUT (F5)."
echo "========================================================"
