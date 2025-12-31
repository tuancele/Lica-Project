#!/bin/bash

echo "🚀 Đang thiết lập Database Hành chính Việt Nam (Provinces/Districts/Wards)..."

# ==============================================================================
# 1. MIGRATION: Tạo bảng Tỉnh, Huyện, Xã
# ==============================================================================
echo "📦 Tạo Migrations..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/database/migrations/2025_02_02_000003_create_vietnam_locations_table.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('provinces')) {
            Schema::create('provinces', function (Blueprint $table) {
                $table->string('code')->primary(); // Mã GSO (01, 79...)
                $table->string('name');
                $table->string('type')->nullable(); // Tỉnh / Thành phố TW
                $table->string('slug')->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('districts')) {
            Schema::create('districts', function (Blueprint $table) {
                $table->string('code')->primary();
                $table->string('province_code')->index();
                $table->string('name');
                $table->string('type')->nullable();
                $table->string('slug')->nullable();
                $table->foreign('province_code')->references('code')->on('provinces')->onDelete('cascade');
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('wards')) {
            Schema::create('wards', function (Blueprint $table) {
                $table->string('code')->primary();
                $table->string('district_code')->index();
                $table->string('name');
                $table->string('type')->nullable();
                $table->string('slug')->nullable();
                $table->foreign('district_code')->references('code')->on('districts')->onDelete('cascade');
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('wards');
        Schema::dropIfExists('districts');
        Schema::dropIfExists('provinces');
    }
};
EOF

# ==============================================================================
# 2. MODELS: Province, District, Ward
# ==============================================================================
echo "📝 Tạo Models..."

cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Models/Province.php
<?php
namespace Modules\IAM\Models;
use Illuminate\Database\Eloquent\Model;

class Province extends Model
{
    protected $primaryKey = 'code';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];

    public function districts() {
        return $this->hasMany(District::class, 'province_code', 'code');
    }
}
EOF

cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Models/District.php
<?php
namespace Modules\IAM\Models;
use Illuminate\Database\Eloquent\Model;

class District extends Model
{
    protected $primaryKey = 'code';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];

    public function province() {
        return $this->belongsTo(Province::class, 'province_code', 'code');
    }
    public function wards() {
        return $this->hasMany(Ward::class, 'district_code', 'code');
    }
}
EOF

cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Models/Ward.php
<?php
namespace Modules\IAM\Models;
use Illuminate\Database\Eloquent\Model;

class Ward extends Model
{
    protected $primaryKey = 'code';
    public $incrementing = false;
    protected $keyType = 'string';
    protected $guarded = [];

    public function district() {
        return $this->belongsTo(District::class, 'district_code', 'code');
    }
}
EOF

# ==============================================================================
# 3. SEEDER: Tự động tải JSON từ Github và Insert
# ==============================================================================
echo "🌱 Tạo Seeder Import dữ liệu..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/database/seeders/VietnamLocationsSeeder.php
<?php

namespace Modules\IAM\Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class VietnamLocationsSeeder extends Seeder
{
    public function run()
    {
        // URL JSON chuẩn từ kenzouno1 (được cập nhật thường xuyên)
        $url = 'https://raw.githubusercontent.com/kenzouno1/DiaGioiHanhChinhVN/master/data.json';
        
        $this->command->info("Downloading data from GitHub...");
        try {
            $jsonData = Http::get($url)->json();
        } catch (\Exception $e) {
            $this->command->error("Failed to download JSON: " . $e->getMessage());
            return;
        }

        if (!$jsonData) {
            $this->command->error("Empty data received.");
            return;
        }

        $this->command->info("Importing Provinces, Districts, Wards...");
        
        DB::beginTransaction();
        try {
            foreach ($jsonData as $prov) {
                // Insert Province
                DB::table('provinces')->updateOrInsert(
                    ['code' => $prov['Id']],
                    [
                        'name' => $prov['Name'],
                        'type' => '', // JSON này không có type, có thể tự xử lý nếu cần
                        'slug' => Str::slug($prov['Name']),
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]
                );

                if (isset($prov['Districts'])) {
                    foreach ($prov['Districts'] as $dist) {
                        // Insert District
                        DB::table('districts')->updateOrInsert(
                            ['code' => $dist['Id']],
                            [
                                'province_code' => $prov['Id'],
                                'name' => $dist['Name'],
                                'slug' => Str::slug($dist['Name']),
                                'created_at' => now(),
                                'updated_at' => now(),
                            ]
                        );

                        if (isset($dist['Wards'])) {
                            $wardsData = [];
                            foreach ($dist['Wards'] as $ward) {
                                // Batch Insert Wards để tối ưu
                                $wardsData[] = [
                                    'code' => $ward['Id'],
                                    'district_code' => $dist['Id'],
                                    'name' => $ward['Name'],
                                    'slug' => Str::slug($ward['Name']),
                                    'created_at' => now(),
                                    'updated_at' => now(),
                                ];
                            }
                            // Sử dụng upsert cho Wards để nhanh hơn
                            if (!empty($wardsData)) {
                                DB::table('wards')->upsert($wardsData, ['code'], ['name', 'district_code', 'updated_at']);
                            }
                        }
                    }
                }
            }
            DB::commit();
            $this->command->info("✅ Import successful!");
        } catch (\Exception $e) {
            DB::rollBack();
            $this->command->error("Import failed: " . $e->getMessage());
        }
    }
}
EOF

# ==============================================================================
# 4. CONTROLLER: API Lấy danh sách
# ==============================================================================
echo "⚙️ Cập nhật LocationController..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Http/Controllers/LocationController.php
<?php

namespace Modules\IAM\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\IAM\Models\Province;
use Modules\IAM\Models\District;
use Modules\IAM\Models\Ward;

class LocationController extends Controller
{
    // Lấy tất cả tỉnh thành
    public function getProvinces()
    {
        // Cache vĩnh viễn hoặc thời gian dài vì ít thay đổi
        $data = cache()->remember('locations_provinces', 86400 * 30, function () {
            return Province::select('code', 'name')->orderBy('code')->get();
        });
        return response()->json(['status' => 200, 'data' => $data]);
    }

    // Lấy quận huyện theo tỉnh
    public function getDistricts($province_code)
    {
        $data = cache()->remember("locations_districts_{$province_code}", 86400 * 30, function () use ($province_code) {
            return District::select('code', 'name')->where('province_code', $province_code)->orderBy('code')->get();
        });
        return response()->json(['status' => 200, 'data' => $data]);
    }

    // Lấy xã phường theo quận
    public function getWards($district_code)
    {
        $data = cache()->remember("locations_wards_{$district_code}", 86400 * 30, function () use ($district_code) {
            return Ward::select('code', 'name')->where('district_code', $district_code)->orderBy('code')->get();
        });
        return response()->json(['status' => 200, 'data' => $data]);
    }
}
EOF

# ==============================================================================
# 5. ROUTE: Thêm Route Location
# ==============================================================================
echo "🔗 Cập nhật Route..."
# Thêm vào file routes/api.php của module IAM
# Lưu ý: Cần thêm use LocationController ở đầu file, đoạn script này sẽ append vào cuối
cat << 'EOF' >> /var/www/lica-project/backend/Modules/IAM/routes/api.php

use Modules\IAM\Http\Controllers\LocationController;

// Public routes cho Location (không cần đăng nhập cũng lấy được để fill form)
Route::prefix('v1/location')->group(function () {
    Route::get('/provinces', [LocationController::class, 'getProvinces']);
    Route::get('/districts/{province_code}', [LocationController::class, 'getDistricts']);
    Route::get('/wards/{district_code}', [LocationController::class, 'getWards']);
});
EOF

# ==============================================================================
# 6. RUN
# ==============================================================================
echo "🔄 Chạy Migration & Seeding..."
cd /var/www/lica-project/backend
php artisan migrate --force

# Chạy Seeder
# Cần dump-autoload để laravel nhận class seeder mới
composer dump-autoload
php artisan db:seed --class="Modules\\IAM\\Database\\Seeders\\VietnamLocationsSeeder"

echo "✅ Hoàn tất! Đã import danh sách tỉnh thành."
