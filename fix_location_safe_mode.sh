#!/bin/bash

BACKEND_ROOT="/var/www/lica-project/backend"

echo "========================================================"
echo "   FIX LOCATION: SAFE MODE (NO ROOT REQUIRED)"
echo "========================================================"

# 1. Cập nhật LocationController (Hỗ trợ đa Database)
echo ">>> [1/3] Cập nhật LocationController..."
cat << 'EOF' > $BACKEND_ROOT/Modules/IAM/app/Http/Controllers/LocationController.php
<?php

namespace Modules\IAM\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\IAM\Models\Province;
use Modules\IAM\Models\District;
use Modules\IAM\Models\Ward;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class LocationController extends Controller
{
    public function getProvinces() {
        try {
            $data = Province::select('code', 'name', 'full_name')->orderBy('code')->get();
            return response()->json(['status' => 200, 'data' => $data]);
        } catch (\Exception $e) {
            Log::error("Location Error: " . $e->getMessage());
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }

    public function getDistricts($p) {
        try {
            $data = District::select('code', 'name', 'full_name')->where('province_code', $p)->orderBy('code')->get();
            return response()->json(['status' => 200, 'data' => $data]);
        } catch (\Exception $e) { return response()->json(['status' => 500], 500); }
    }

    public function getWards($d) {
        try {
            $data = Ward::select('code', 'name', 'full_name')->where('district_code', $d)->orderBy('code')->get();
            return response()->json(['status' => 200, 'data' => $data]);
        } catch (\Exception $e) { return response()->json(['status' => 500], 500); }
    }

    public function search(Request $request)
    {
        try {
            $q = trim($request->get('q'));
            if (!$q || strlen($q) < 2) return response()->json(['status' => 200, 'data' => []]);

            $slug = Str::slug($q, ' '); 
            
            // Tự động chọn toán tử phù hợp với DB
            $op = DB::connection()->getDriverName() === 'pgsql' ? 'ILIKE' : 'LIKE';

            $results = Ward::query()
                ->join('districts', 'wards.district_code', '=', 'districts.code')
                ->join('provinces', 'districts.province_code', '=', 'provinces.code')
                ->where(function($query) use ($q, $slug, $op) {
                    $query->where('wards.name', $op, "%{$q}%")
                          ->orWhere('districts.name', $op, "%{$q}%")
                          ->orWhere('provinces.name', $op, "%{$q}%")
                          ->orWhere('wards.code_name', $op, "%{$slug}%")
                          ->orWhere('districts.code_name', $op, "%{$slug}%")
                          ->orWhere('provinces.code_name', $op, "%{$slug}%");
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

# 2. Tạo SafeCleanSeeder (Xóa dữ liệu chuẩn, không cần quyền cao)
echo ">>> [2/3] Tạo SafeCleanSeeder..."
mkdir -p $BACKEND_ROOT/Modules/IAM/database/seeders

cat << 'EOF' > $BACKEND_ROOT/Modules/IAM/database/seeders/SafeCleanSeeder.php
<?php

namespace Modules\IAM\Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

class SafeCleanSeeder extends Seeder
{
    public function run(): void
    {
        // Xóa bảng theo thứ tự con -> cha để tránh lỗi khóa ngoại
        // Không dùng TRUNCATE CASCADE vì cần quyền owner/superuser trên một số setup
        
        echo "1. Cleaning Wards...\n";
        Schema::dropIfExists('wards');
        
        echo "2. Cleaning Districts...\n";
        Schema::dropIfExists('districts');
        
        echo "3. Cleaning Provinces...\n";
        Schema::dropIfExists('provinces');
        
        // Xóa log migration để chạy lại
        DB::table('migrations')->where('migration', 'like', '%create_vietnam_locations_table%')->delete();
        
        echo "DB Cleaned Successfully!\n";
    }
}
EOF

# 3. Chạy lại toàn bộ quy trình
echo ">>> [3/3] Reset Database & Import Data..."
cd $BACKEND_ROOT
composer dump-autoload

# Xóa bảng cũ
php artisan db:seed --class="Modules\IAM\Database\Seeders\SafeCleanSeeder" --force

# Tạo bảng mới (Migration sẽ tự chạy lại vì log đã xóa)
php artisan migrate --force

# Nạp dữ liệu (VietnamLocationsSeeder đã tạo ở bước trước)
php artisan db:seed --class="Modules\IAM\Database\Seeders\VietnamLocationsSeeder" --force

# Xóa cache
php artisan cache:clear
php artisan route:clear

echo "========================================================"
echo "   ĐÃ HOÀN TẤT! DỮ LIỆU ĐÃ SẴN SÀNG."
echo "   HÃY F5 LẠI TRANG CHECKOUT."
echo "========================================================"
