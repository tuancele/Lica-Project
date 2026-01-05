#!/bin/bash

BACKEND_ROOT="/var/www/lica-project/backend"

echo "========================================================"
echo "   FIX LỖI TÌM KIẾM ĐỊA CHÍNH (MYSQL COMPATIBILITY)"
echo "========================================================"

# Cập nhật LocationController
echo ">>> Updating LocationController.php..."
cat << 'EOF' > $BACKEND_ROOT/Modules/IAM/app/Http/Controllers/LocationController.php
<?php

namespace Modules\IAM\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\IAM\Models\Province;
use Modules\IAM\Models\District;
use Modules\IAM\Models\Ward;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class LocationController extends Controller
{
    // Lấy danh sách Tỉnh/Thành phố (Dropdown cấp 1)
    public function getProvinces() {
        // Cache 1 ngày để giảm tải DB
        $data = cache()->remember('loc_prov_v2', 86400, function() {
            return Province::select('code', 'name', 'full_name')->orderBy('code')->get();
        });
        return response()->json(['status' => 200, 'data' => $data]);
    }

    // Lấy Quận/Huyện (Dropdown cấp 2)
    public function getDistricts($p) {
        $data = cache()->remember("loc_dist_v2_$p", 86400, function() use ($p) {
            return District::select('code', 'name', 'full_name')
                ->where('province_code', $p)
                ->orderBy('code')
                ->get();
        });
        return response()->json(['status' => 200, 'data' => $data]);
    }

    // Lấy Phường/Xã (Dropdown cấp 3)
    public function getWards($d) {
        $data = cache()->remember("loc_ward_v2_$d", 86400, function() use ($d) {
            return Ward::select('code', 'name', 'full_name')
                ->where('district_code', $d)
                ->orderBy('code')
                ->get();
        });
        return response()->json(['status' => 200, 'data' => $data]);
    }

    // API TÌM KIẾM THÔNG MINH (SMART SEARCH)
    // Fix lỗi: Dùng LIKE thay vì ILIKE, dùng column code_name thay vì slug
    public function search(Request $request)
    {
        $q = trim($request->get('q'));
        
        if (!$q || strlen($q) < 2) return response()->json(['status' => 200, 'data' => []]);

        // Tạo slug tìm kiếm (VD: "Hà Nội" -> "ha-noi")
        // Thay dấu gạch ngang bằng % để tìm kiếm linh hoạt hơn
        $slug = Str::slug($q, ' '); 

        $results = Ward::query()
            ->join('districts', 'wards.district_code', '=', 'districts.code')
            ->join('provinces', 'districts.province_code', '=', 'provinces.code')
            ->where(function($query) use ($q, $slug) {
                // 1. Tìm theo tên có dấu (MySQL mặc định case-insensitive với LIKE)
                $query->where('wards.name', 'LIKE', "%{$q}%")
                      ->orWhere('districts.name', 'LIKE', "%{$q}%")
                      ->orWhere('provinces.name', 'LIKE', "%{$q}%")
                
                // 2. Tìm theo không dấu (Cột code_name trong DB)
                      ->orWhere('wards.code_name', 'LIKE', "%{$slug}%")
                      ->orWhere('districts.code_name', 'LIKE', "%{$slug}%")
                      ->orWhere('provinces.code_name', 'LIKE', "%{$slug}%");
            })
            ->limit(15)
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
    }
}
EOF

# Xóa cache để code mới có hiệu lực ngay
echo ">>> Clearing cache..."
cd $BACKEND_ROOT
php artisan cache:clear
php artisan config:clear

echo "========================================================"
echo "   ĐÃ SỬA XONG API LOCATION! HÃY THỬ LẠI TRÊN FE."
echo "========================================================"
