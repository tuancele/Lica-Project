<?php
use Illuminate\Support\Facades\Route;
use Modules\Product\Http\Controllers\ProductController;
use Modules\Product\Http\Controllers\CategoryController;

Route::prefix('v1/product')->group(function () {
    Route::get('/', [ProductController::class, 'index']);
    Route::post('/', [ProductController::class, 'store']);
    Route::get('/{id}', [ProductController::class, 'show']);
    Route::put('/{id}', [ProductController::class, 'update']);
    Route::delete('/{id}', [ProductController::class, 'destroy']);
    Route::get('/seed', [ProductController::class, 'seed']); // Để tạo sản phẩm mẫu nếu cần
});

// Category API
Route::prefix('v1/category')->group(function () {
    Route::get('/', [CategoryController::class, 'index']); // Lấy list
    Route::post('/', [CategoryController::class, 'store']); // Tạo mới
    Route::get('/setup', [CategoryController::class, 'setupHasaki']); // <--- API KHỞI TẠO
});
