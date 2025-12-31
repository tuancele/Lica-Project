#!/bin/bash

echo "🧠 Đang nâng cấp thuật toán tìm kiếm (Hỗ trợ không dấu, chữ thường)..."

# ==============================================================================
# CẬP NHẬT LocationController
# ==============================================================================
cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Http/Controllers/LocationController.php
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
    public function getProvinces() {
        return response()->json(['status' => 200, 'data' => cache()->remember('loc_prov', 86400, fn()=>Province::select('code','name')->orderBy('code')->get())]);
    }
    public function getDistricts($p) {
        return response()->json(['status' => 200, 'data' => cache()->remember("loc_dist_$p", 86400, fn()=>District::select('code','name')->where('province_code',$p)->orderBy('code')->get())]);
    }
    public function getWards($d) {
        return response()->json(['status' => 200, 'data' => cache()->remember("loc_ward_$d", 86400, fn()=>Ward::select('code','name')->where('district_code',$d)->orderBy('code')->get())]);
    }

    // API TÌM KIẾM THÔNG MINH (SMART SEARCH)
    public function search(Request $request)
    {
        $q = trim($request->get('q'));
        
        // Nếu từ khóa quá ngắn, trả về rỗng
        if (!$q || strlen($q) < 2) return response()->json(['status' => 200, 'data' => []]);

        // 1. Chuẩn hóa từ khóa sang dạng slug (VD: "Đại Mỗ" -> "dai-mo", "Hà Nội" -> "ha-noi")
        $slug = Str::slug($q);

        // 2. Truy vấn
        $results = Ward::query()
            ->join('districts', 'wards.district_code', '=', 'districts.code')
            ->join('provinces', 'districts.province_code', '=', 'provinces.code')
            ->where(function($query) use ($q, $slug) {
                // Ưu tiên 1: Tìm theo tên chính xác (ILIKE để không phân biệt hoa thường)
                $query->where('wards.name', 'ILIKE', "%{$q}%")
                
                // Ưu tiên 2: Tìm theo slug (Hỗ trợ gõ không dấu: "dai mo" -> khớp "dai-mo")
                      ->orWhere('wards.slug', 'ILIKE', "%{$slug}%")
                
                // Ưu tiên 3: Tìm rộng ra Quận/Huyện (VD user gõ "Nam Từ Liêm")
                      ->orWhere('districts.name', 'ILIKE', "%{$q}%")
                      ->orWhere('districts.slug', 'ILIKE', "%{$slug}%");
            })
            // Sắp xếp: Kết quả nào khớp chính xác tên lên đầu, sau đó đến khớp slug
            ->orderByRaw("CASE WHEN wards.name ILIKE ? THEN 1 WHEN wards.slug ILIKE ? THEN 2 ELSE 3 END", ["%{$q}%", "%{$slug}%"])
            ->limit(20)
            ->select(
                'wards.code as ward_code',
                'wards.name as ward_name',
                'districts.code as district_code',
                'districts.name as district_name',
                'provinces.code as province_code',
                'provinces.name as province_name'
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

# ==============================================================================
# RESTART & CLEAR CACHE
# ==============================================================================
echo "🧹 Xóa Cache Route..."
cd /var/www/lica-project/backend
php artisan route:clear
php artisan config:clear

echo "✅ Đã nâng cấp thuật toán tìm kiếm! Hãy thử gõ 'dai mo' hoặc 'ha noi'."
