<?php

use Illuminate\Support\Facades\Route;
use Modules\Order\Http\Controllers\OrderController;

Route::prefix('v1/order')->group(function () {
    // Client
    Route::post('/checkout', [OrderController::class, 'checkout']);
    Route::get('/success/{hash}', [OrderController::class, 'getOrderByHash']);

    // Admin
    Route::get('/', [OrderController::class, 'index']); // List orders
    Route::get('/{id}', [OrderController::class, 'show']); // Detail
    Route::put('/{id}/status', [OrderController::class, 'updateStatus']); // Update status
});
