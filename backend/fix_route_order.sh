#!/bin/bash

PROJECT_DIR="/var/www/lica-project/backend"
ROUTE_FILE="$PROJECT_DIR/Modules/Product/routes/api.php"

echo ">>> BẮT ĐẦU SỬA LỖI XUNG ĐỘT ROUTE..."

# Ghi đè lại file route với thứ tự đúng
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
    // --- QUAN TRỌNG: Đặt các Route tĩnh (Static) lên TRƯỚC ---
    Route::apiResource('brands', BrandController::class);
    Route::apiResource('origins', OriginController::class);
    Route::apiResource('units', UnitController::class);
    Route::apiResource('skin-types', SkinTypeController::class);

    // --- Đặt Route động (Wildcard {id}) xuống CUỐI CÙNG ---
    Route::get('/', [ProductController::class, 'index']);
    Route::post('/', [ProductController::class, 'store']);
    
    // Nếu để dòng này ở trên, nó sẽ nuốt mất chữ 'brands' và coi đó là ID
    Route::get('/{id}', [ProductController::class, 'show']);
    Route::put('/{id}', [ProductController::class, 'update']);
    Route::delete('/{id}', [ProductController::class, 'destroy']);
});

// 2. Nhóm API Danh mục
Route::prefix('v1/category')->group(function () {
    Route::get('/', [CategoryController::class, 'index']);
    Route::post('/', [CategoryController::class, 'store']);
});
PHP

# Xóa cache route để áp dụng thay đổi
echo ">>> Clearing Route Cache..."
cd "$PROJECT_DIR"
php artisan route:clear
php artisan config:clear

# Restart service cho chắc
sudo service php8.2-fpm reload 2>/dev/null || sudo service php8.3-fpm reload 2>/dev/null

echo "--------------------------------------------------------"
echo "✅ ĐÃ SỬA XONG THỨ TỰ ROUTE!"
echo "👉 Hãy F5 lại trang Admin. Lỗi 500 và lỗi e.map sẽ biến mất."
echo "--------------------------------------------------------"
