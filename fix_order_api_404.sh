#!/bin/bash

echo "🚑 Đang sửa lỗi API Orders 404 Not Found..."

# ==============================================================================
# 1. BACKEND: Đăng ký lại Route cho Order
# ==============================================================================
echo "🔗 Cấu hình lại Route Backend..."

cat << 'EOF' > /var/www/lica-project/backend/Modules/Order/routes/api.php
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
EOF

# ==============================================================================
# 2. FRONTEND ADMIN: Tạo trang Settings (Fix lỗi 404 Settings)
# ==============================================================================
echo "💻 Tạo trang Settings (tránh lỗi 404 sidebar)..."
mkdir -p /var/www/lica-project/apps/admin/app/settings

cat << 'EOF' > /var/www/lica-project/apps/admin/app/settings/page.tsx
"use client";
import { Settings } from "lucide-react";

export default function SettingsPage() {
  return (
    <div className="p-6 bg-gray-50 min-h-screen">
      <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2 mb-6">
        <Settings className="text-blue-600"/> Cấu hình hệ thống
      </h1>
      <div className="bg-white p-10 rounded-xl shadow border text-center text-gray-500">
        Tính năng đang được phát triển.
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# 3. QUAN TRỌNG: CLEAR CACHE BACKEND
# ==============================================================================
echo "🧹 Xóa Cache Route (Bắt buộc)..."
cd /var/www/lica-project/backend

# Xóa cache route cũ
php artisan route:clear
# Cache lại route mới (để tăng tốc và đảm bảo nhận diện)
php artisan route:cache

# Restart Admin để nhận trang settings
echo "🔄 Restart Admin..."
pm2 restart lica-admin

echo "✅ Đã sửa xong! Hãy tải lại trang Admin Orders."
