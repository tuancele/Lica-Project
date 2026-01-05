<?php

namespace Modules\IAM\Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

class CleanLocationSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Xóa dữ liệu theo thứ tự ngược để tránh lỗi khóa ngoại
        // Wards phụ thuộc Districts -> Xóa Wards trước
        // Districts phụ thuộc Provinces -> Xóa Districts trước
        
        echo "Deleting old data...\n";
        
        if (Schema::hasTable('wards')) {
            DB::table('wards')->delete(); // Delete thay vì Truncate để an toàn hơn
        }
        
        if (Schema::hasTable('districts')) {
            DB::table('districts')->delete();
        }
        
        if (Schema::hasTable('provinces')) {
            DB::table('provinces')->delete();
        }

        // 2. Drop bảng luôn để tái tạo schema mới
        echo "Dropping tables...\n";
        Schema::disableForeignKeyConstraints(); // Thử tắt check (chỉ work trên 1 số driver)
        Schema::dropIfExists('wards');
        Schema::dropIfExists('districts');
        Schema::dropIfExists('provinces');
        Schema::enableForeignKeyConstraints();
        
        // 3. Xóa log migration cũ
        DB::table('migrations')->where('migration', 'like', '%create_vietnam_locations_table%')->delete();
        
        echo "Đã xóa bảng cũ thành công!\n";
    }
}
