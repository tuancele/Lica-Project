#!/bin/bash

BE_DIR="/var/www/lica-project/backend"

echo "========================================================"
echo "   KHÔI PHỤC API QUẢN LÝ VOUCHER (ADMIN)"
echo "========================================================"

# Cập nhật file routes/api.php của Module Order
# Kết hợp cả Route cho Checkout (User) và CRUD (Admin)
echo ">>> Updating Routes..."
cat << 'EOF' > $BE_DIR/Modules/Order/routes/api.php
<?php

use Illuminate\Support\Facades\Route;
use Modules\Order\Http\Controllers\OrderController;
use Modules\Order\Http\Controllers\CouponController;

// 1. Group Order (Checkout, Tra cứu đơn)
Route::prefix('v1/order')->group(function () {
    Route::post('/checkout', [OrderController::class, 'checkout']);
    Route::post('/check-coupon', [CouponController::class, 'check']);
    Route::get('/success/{hash}', [OrderController::class, 'getOrderByHash']);
});

// 2. Group Marketing (Quản lý Voucher)
Route::prefix('v1/marketing')->group(function () {
    // API Public cho khách hàng (Lấy voucher khả dụng)
    Route::get('/coupons/available', [CouponController::class, 'getAvailableCoupons']);

    // API CRUD cho Admin (Thêm, Sửa, Xóa, Danh sách) -> Đã bị thiếu trước đó
    Route::get('/coupons', [CouponController::class, 'index']);       // Lấy danh sách
    Route::post('/coupons', [CouponController::class, 'store']);      // Tạo mới
    Route::get('/coupons/{id}', [CouponController::class, 'show']);   // Xem chi tiết
    Route::put('/coupons/{id}', [CouponController::class, 'update']); // Cập nhật
    Route::delete('/coupons/{id}', [CouponController::class, 'destroy']); // Xóa
});
EOF

# Xóa cache route để hệ thống nhận diện đường dẫn mới
echo ">>> Clearing Route Cache..."
cd $BE_DIR
php artisan route:clear
php artisan config:clear

echo "========================================================"
echo "   ĐÃ KHÔI PHỤC API VOUCHER THÀNH CÔNG!"
echo "   VUI LÒNG THỬ LẠI TRÊN TRANG ADMIN."
echo "========================================================"
