<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Thương hiệu
        if (!Schema::hasTable('brands')) {
            Schema::create('brands', function (Blueprint $table) {
                $table->id();
                $table->string('name');
                $table->string('slug')->nullable()->index();
                $table->string('logo')->nullable();
                $table->text('description')->nullable();
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        // 2. Xuất xứ (Quốc gia)
        if (!Schema::hasTable('origins')) {
            Schema::create('origins', function (Blueprint $table) {
                $table->id();
                $table->string('name'); // VD: Hàn Quốc
                $table->string('code', 10)->nullable(); // VD: KR
                $table->timestamps();
            });
        }

        // 3. Đơn vị tính / Dung tích
        if (!Schema::hasTable('units')) {
            Schema::create('units', function (Blueprint $table) {
                $table->id();
                $table->string('name'); // VD: Chai, Hộp, ml, gram
                $table->string('type')->default('unit'); // unit (đơn vị) hoặc capacity (dung tích)
                $table->timestamps();
            });
        }

        // 4. Loại da (Skin Types)
        if (!Schema::hasTable('skin_types')) {
            Schema::create('skin_types', function (Blueprint $table) {
                $table->id();
                $table->string('name'); // VD: Da dầu
                $table->string('code')->nullable();
                $table->timestamps();
            });
        }

        // 5. Cập nhật bảng Products (Thêm khóa ngoại)
        if (Schema::hasTable('products')) {
            Schema::table('products', function (Blueprint $table) {
                // Xóa cột brand cũ nếu nó là string (để thay bằng ID)
                // Lưu ý: Nếu có dữ liệu cũ cần migrate tay, ở đây ta làm mới
                if (Schema::hasColumn('products', 'brand') && !Schema::hasColumn('products', 'brand_id')) {
                    $table->dropColumn('brand'); 
                }

                if (!Schema::hasColumn('products', 'brand_id')) 
                    $table->foreignId('brand_id')->nullable()->constrained('brands')->nullOnDelete();
                
                if (!Schema::hasColumn('products', 'origin_id')) 
                    $table->foreignId('origin_id')->nullable()->constrained('origins')->nullOnDelete();
                
                if (!Schema::hasColumn('products', 'unit_id')) 
                    $table->foreignId('unit_id')->nullable()->constrained('units')->nullOnDelete();
                
                // Skin Types thường là Many-to-Many (1 sp dùng cho nhiều loại da)
                // Nhưng để đơn giản giai đoạn 1, ta lưu JSON mảng ID
                if (!Schema::hasColumn('products', 'skin_type_ids')) 
                    $table->json('skin_type_ids')->nullable()->comment('Lưu mảng ID [1,2,3]');
            });
        }
    }

    public function down(): void
    {
        // An toàn: Không drop table để tránh mất dữ liệu khi rollback
    }
};
