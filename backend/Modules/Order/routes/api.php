<?php

use Illuminate\Support\Facades\Route;
use Modules\Order\Http\Controllers\OrderController;
use Modules\Order\Http\Controllers\CouponController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
*/

// Group: Order Management
Route::prefix('v1/orders')->group(function () {
    Route::get('/', [OrderController::class, 'index']);       // API Danh sách đơn hàng (Bị lỗi 404 ở đây)
    Route::get('/{id}', [OrderController::class, 'show']);    // API Chi tiết đơn hàng
    Route::put('/{id}/status', [OrderController::class, 'updateStatus']); // API Cập nhật trạng thái
});

// Group: Checkout & Public Order
Route::prefix('v1/order')->group(function () {
    Route::post('/checkout', [OrderController::class, 'checkout']);
    Route::post('/check-coupon', [OrderController::class, 'checkCoupon']);
    Route::get('/success/{hash}', [OrderController::class, 'getOrderByHash']);
});

// Group: Marketing / Coupons
Route::prefix('v1/marketing/coupons')->group(function () {
    Route::get('/', [CouponController::class, 'index']);
    Route::post('/', [CouponController::class, 'store']);
    Route::get('/available', [CouponController::class, 'getAvailable']); // API lấy voucher cho user
    Route::get('/{id}', [CouponController::class, 'show']);
    Route::put('/{id}', [CouponController::class, 'update']);
    Route::delete('/{id}', [CouponController::class, 'destroy']);
});
