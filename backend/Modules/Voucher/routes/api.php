<?php
use Illuminate\Support\Facades\Route;
use Modules\Voucher\Http\Controllers\VoucherController;

Route::prefix('v1/voucher')->group(function () {
    Route::get('/', [VoucherController::class, 'index']);
    Route::post('/', [VoucherController::class, 'store']);
});
