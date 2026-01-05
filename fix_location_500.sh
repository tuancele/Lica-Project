#!/bin/bash

BACKEND_ROOT="/var/www/lica-project/backend"

echo "========================================================"
echo "   FIX LỖI 500 API LOCATION (BỎ CACHE & DEBUG)"
echo "========================================================"

# 1. Cập nhật LocationController (Safe Mode: No Cache, Full Try-Catch)
echo ">>> [1/2] Update LocationController.php..."
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
            // Tạm thời query trực tiếp không qua cache để tránh lỗi quyền/redis
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

    // Tìm kiếm thông minh
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

# 2. Xóa Cache & Cấp quyền lại thư mục storage (Nguyên nhân phổ biến gây lỗi cache)
echo ">>> [2/2] Fix Permissions & Clear Cache..."
cd $BACKEND_ROOT
php artisan route:clear
php artisan config:clear
php artisan cache:clear

# Đảm bảo quyền ghi cho logs và cache
chown -R www-data:www-data storage
chmod -R 775 storage

echo "========================================================"
echo "   ĐÃ SỬA XONG! VUI LÒNG RELOAD TRANG CHECKOUT."
echo "========================================================"
