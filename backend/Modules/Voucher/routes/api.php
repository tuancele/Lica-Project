<?php

use Illuminate\Support\Facades\Route;
use Modules\Voucher\Http\Controllers\VoucherController;

Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::apiResource('vouchers', VoucherController::class)->names('voucher');
});
