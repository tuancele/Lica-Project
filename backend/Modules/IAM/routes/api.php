<?php

use Illuminate\Support\Facades\Route;
use Modules\IAM\Http\Controllers\AuthController;

Route::prefix('v1/auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
});

Route::middleware(['auth:sanctum'])->prefix('v1/profile')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::get('/orders', [AuthController::class, 'getOrders']);
    Route::get('/addresses', [AuthController::class, 'getAddresses']);
    Route::post('/addresses', [AuthController::class, 'addAddress']);
    Route::get('/wishlist', [AuthController::class, 'getWishlist']);
});

use Modules\IAM\Http\Controllers\LocationController;

// Public routes cho Location (không cần đăng nhập cũng lấy được để fill form)
Route::prefix('v1/location')->group(function () {
    Route::get('/provinces', [LocationController::class, 'getProvinces']);
    Route::get('/districts/{province_code}', [LocationController::class, 'getDistricts']);
    Route::get('/wards/{district_code}', [LocationController::class, 'getWards']);
    Route::get('/search', [LocationController::class, 'search']);
});

use Modules\IAM\Http\Controllers\UserController;

// Admin Management Routes
Route::prefix('v1/users')->group(function () {
    Route::get('/', [UserController::class, 'index']);
    Route::get('/{id}', [UserController::class, 'show']);
    Route::delete('/{id}', [UserController::class, 'destroy']);
});
