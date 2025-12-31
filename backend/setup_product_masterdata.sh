#!/bin/bash

# --- CẤU HÌNH ---
PROJECT_DIR="/var/www/lica-project/backend"
MODULE_DIR="$PROJECT_DIR/Modules/Product"
APP_DIR="$MODULE_DIR/app"

echo ">>> BẮT ĐẦU NÂNG CẤP PRODUCT MODULE (MASTER DATA)..."

# ====================================================
# 1. TẠO MIGRATION CHO CÁC BẢNG MỚI
# ====================================================
echo ">>> [1/5] Creating Migrations..."
MIGRATION_FILE="$MODULE_DIR/database/migrations/2025_01_02_000001_create_product_attributes_tables.php"

cat > "$MIGRATION_FILE" <<PHP
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
            Schema::create('brands', function (Blueprint \$table) {
                \$table->id();
                \$table->string('name');
                \$table->string('slug')->nullable()->index();
                \$table->string('logo')->nullable();
                \$table->text('description')->nullable();
                \$table->boolean('is_active')->default(true);
                \$table->timestamps();
            });
        }

        // 2. Xuất xứ (Quốc gia)
        if (!Schema::hasTable('origins')) {
            Schema::create('origins', function (Blueprint \$table) {
                \$table->id();
                \$table->string('name'); // VD: Hàn Quốc
                \$table->string('code', 10)->nullable(); // VD: KR
                \$table->timestamps();
            });
        }

        // 3. Đơn vị tính / Dung tích
        if (!Schema::hasTable('units')) {
            Schema::create('units', function (Blueprint \$table) {
                \$table->id();
                \$table->string('name'); // VD: Chai, Hộp, ml, gram
                \$table->string('type')->default('unit'); // unit (đơn vị) hoặc capacity (dung tích)
                \$table->timestamps();
            });
        }

        // 4. Loại da (Skin Types)
        if (!Schema::hasTable('skin_types')) {
            Schema::create('skin_types', function (Blueprint \$table) {
                \$table->id();
                \$table->string('name'); // VD: Da dầu
                \$table->string('code')->nullable();
                \$table->timestamps();
            });
        }

        // 5. Cập nhật bảng Products (Thêm khóa ngoại)
        if (Schema::hasTable('products')) {
            Schema::table('products', function (Blueprint \$table) {
                // Xóa cột brand cũ nếu nó là string (để thay bằng ID)
                // Lưu ý: Nếu có dữ liệu cũ cần migrate tay, ở đây ta làm mới
                if (Schema::hasColumn('products', 'brand') && !Schema::hasColumn('products', 'brand_id')) {
                    \$table->dropColumn('brand'); 
                }

                if (!Schema::hasColumn('products', 'brand_id')) 
                    \$table->foreignId('brand_id')->nullable()->constrained('brands')->nullOnDelete();
                
                if (!Schema::hasColumn('products', 'origin_id')) 
                    \$table->foreignId('origin_id')->nullable()->constrained('origins')->nullOnDelete();
                
                if (!Schema::hasColumn('products', 'unit_id')) 
                    \$table->foreignId('unit_id')->nullable()->constrained('units')->nullOnDelete();
                
                // Skin Types thường là Many-to-Many (1 sp dùng cho nhiều loại da)
                // Nhưng để đơn giản giai đoạn 1, ta lưu JSON mảng ID
                if (!Schema::hasColumn('products', 'skin_type_ids')) 
                    \$table->json('skin_type_ids')->nullable()->comment('Lưu mảng ID [1,2,3]');
            });
        }
    }

    public function down(): void
    {
        // An toàn: Không drop table để tránh mất dữ liệu khi rollback
    }
};
PHP

# ====================================================
# 2. TẠO MODELS
# ====================================================
echo ">>> [2/5] Creating Models..."
mkdir -p "$APP_DIR/Models"

# Hàm tạo Model
create_model() {
    NAME=$1
    TABLE=$2
    cat > "$APP_DIR/Models/$NAME.php" <<PHP
<?php

namespace Modules\Product\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class $NAME extends Model
{
    use HasFactory;
    protected \$table = '$TABLE';
    protected \$guarded = [];
}
PHP
}

create_model "Brand" "brands"
create_model "Origin" "origins"
create_model "Unit" "units"
create_model "SkinType" "skin_types"

# Cập nhật Model Product chính để có relation
PRODUCT_MODEL="$APP_DIR/Models/Product.php"
cat > "$PRODUCT_MODEL" <<PHP
<?php

namespace Modules\Product\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Product extends Model
{
    use HasFactory;

    protected \$guarded = [];

    protected \$casts = [
        'images' => 'array',
        'skin_type_ids' => 'array',
        'is_active' => 'boolean',
    ];

    public function category() {
        return \$this->belongsTo(Category::class);
    }

    public function brand() {
        return \$this->belongsTo(Brand::class);
    }

    public function origin() {
        return \$this->belongsTo(Origin::class);
    }

    public function unit() {
        return \$this->belongsTo(Unit::class);
    }
}
PHP

# ====================================================
# 3. TẠO CONTROLLERS (CRUD CHUẨN)
# ====================================================
echo ">>> [3/5] Creating Controllers..."
CTRL_DIR="$APP_DIR/Http/Controllers"
mkdir -p "$CTRL_DIR"

# Hàm tạo Controller chuẩn API
create_controller() {
    NAME=$1
    MODEL=$2
    cat > "$CTRL_DIR/${NAME}Controller.php" <<PHP
<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\\$MODEL;

class ${NAME}Controller extends Controller
{
    public function index(Request \$request)
    {
        \$query = $MODEL::query();
        if (\$request->has('q')) {
            \$query->where('name', 'like', "%" . \$request->q . "%");
        }
        return response()->json(['status' => 200, 'data' => \$query->latest()->get()]);
    }

    public function store(Request \$request)
    {
        \$request->validate(['name' => 'required|string|max:255']);
        \$item = $MODEL::create(\$request->all());
        return response()->json(['status' => 201, 'data' => \$item]);
    }

    public function show(\$id)
    {
        \$item = $MODEL::find(\$id);
        if (!\$item) return response()->json(['message' => 'Not found'], 404);
        return response()->json(['status' => 200, 'data' => \$item]);
    }

    public function update(Request \$request, \$id)
    {
        \$item = $MODEL::find(\$id);
        if (!\$item) return response()->json(['message' => 'Not found'], 404);
        \$item->update(\$request->all());
        return response()->json(['status' => 200, 'data' => \$item]);
    }

    public function destroy(\$id)
    {
        $MODEL::destroy(\$id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
PHP
}

create_controller "Brand" "Brand"
create_controller "Origin" "Origin"
create_controller "Unit" "Unit"
create_controller "SkinType" "SkinType"

# Cập nhật lại ProductController để nhận các trường mới
cat > "$CTRL_DIR/ProductController.php" <<PHP
<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Product;
use Illuminate\Support\Str;

class ProductController extends Controller
{
    public function index(Request \$request)
    {
        // Eager load các quan hệ để hiển thị tên thay vì ID
        \$query = Product::with(['category', 'brand', 'origin', 'unit']);

        if (\$request->has('q')) {
            \$query->where('name', 'like', "%{\$request->q}%")
                  ->orWhere('sku', 'like', "%{\$request->q}%");
        }
        
        if (\$request->has('category_id')) {
            \$query->where('category_id', \$request->category_id);
        }

        if (\$request->has('brand_id')) {
            \$query->where('brand_id', \$request->brand_id);
        }

        return response()->json(['status' => 200, 'data' => \$query->orderBy('created_at', 'desc')->paginate(20)]);
    }

    public function show(\$id)
    {
        \$product = Product::with(['category', 'brand', 'origin', 'unit'])->find(\$id);
        if (!\$product) return response()->json(['message' => 'Not found'], 404);
        return response()->json(['status' => 200, 'data' => \$product]);
    }

    public function store(Request \$request)
    {
        \$data = \$request->validate([
            'name' => 'required|string|max:255',
            'price' => 'required|numeric|min:0',
            'sku' => 'nullable|string|unique:products,sku',
            'category_id' => 'nullable|exists:categories,id',
            'brand_id' => 'nullable|exists:brands,id',
            'origin_id' => 'nullable|exists:origins,id',
            'unit_id' => 'nullable|exists:units,id',
            'skin_type_ids' => 'nullable|array',
            'images' => 'nullable|array',
            'stock_quantity' => 'integer|min:0',
            'description' => 'nullable|string',
            'short_description' => 'nullable|string',
            'ingredients' => 'nullable|string',
            'usage_instructions' => 'nullable|string',
        ]);

        if (empty(\$request->slug)) {
            \$data['slug'] = Str::slug(\$data['name']) . '-' . uniqid();
        }

        if (!empty(\$data['images']) && is_array(\$data['images'])) {
            \$data['thumbnail'] = \$data['images'][0] ?? null;
        }

        \$product = Product::create(\$data);
        return response()->json(['status' => 201, 'data' => \$product]);
    }

    public function update(Request \$request, \$id)
    {
        \$product = Product::find(\$id);
        if (!\$product) return response()->json(['message' => 'Not found'], 404);

        \$request->validate([
            'name' => 'string|max:255',
            'sku' => 'nullable|string|unique:products,sku,' . \$id,
        ]);

        \$data = \$request->all();
        
        if (\$request->has('images')) {
            \$images = \$request->input('images');
            if (!empty(\$images) && is_array(\$images)) {
                \$data['thumbnail'] = \$images[0] ?? null;
            }
        }

        \$product->update(\$data);
        return response()->json(['status' => 200, 'data' => \$product]);
    }

    public function destroy(\$id)
    {
        Product::destroy(\$id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
PHP

# ====================================================
# 4. CẬP NHẬT ROUTES API
# ====================================================
echo ">>> [4/5] Updating API Routes..."
ROUTE_FILE="$MODULE_DIR/routes/api.php"

cat > "$ROUTE_FILE" <<PHP
<?php

use Illuminate\Support\Facades\Route;
use Modules\Product\Http\Controllers\ProductController;
use Modules\Product\Http\Controllers\CategoryController;
use Modules\Product\Http\Controllers\BrandController;
use Modules\Product\Http\Controllers\OriginController;
use Modules\Product\Http\Controllers\UnitController;
use Modules\Product\Http\Controllers\SkinTypeController;

// 1. Nhóm API Sản phẩm
Route::prefix('v1/product')->group(function () {
    Route::get('/', [ProductController::class, 'index']);
    Route::post('/', [ProductController::class, 'store']);
    Route::get('/{id}', [ProductController::class, 'show']);
    Route::put('/{id}', [ProductController::class, 'update']);
    Route::delete('/{id}', [ProductController::class, 'destroy']);
    
    // Các API Master Data (Con)
    Route::apiResource('brands', BrandController::class);
    Route::apiResource('origins', OriginController::class);
    Route::apiResource('units', UnitController::class);
    Route::apiResource('skin-types', SkinTypeController::class);
});

// 2. Nhóm API Danh mục (Giữ nguyên)
Route::prefix('v1/category')->group(function () {
    Route::get('/', [CategoryController::class, 'index']);
    Route::post('/', [CategoryController::class, 'store']);
});
PHP

# ====================================================
# 5. CHẠY MIGRATION & CLEAR CACHE
# ====================================================
echo ">>> [5/5] Running Migration & Refreshing..."
cd "$PROJECT_DIR"

# Nạp class mới
composer dump-autoload

# Chạy migration để tạo bảng
php artisan module:migrate Product

# Clear cache route
php artisan route:clear
php artisan config:clear

echo "--------------------------------------------------------"
echo "✅ ĐÃ HOÀN TẤT SETUP MASTER DATA SẢN PHẨM!"
echo "👉 Các API mới đã sẵn sàng:"
echo "   - GET /api/v1/product/brands"
echo "   - GET /api/v1/product/origins"
echo "   - GET /api/v1/product/units"
echo "   - GET /api/v1/product/skin-types"
echo "--------------------------------------------------------"
