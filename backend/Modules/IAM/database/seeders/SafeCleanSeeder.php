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
