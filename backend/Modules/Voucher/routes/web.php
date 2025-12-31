<?php

use Illuminate\Support\Facades\Route;
use Modules\Voucher\Http\Controllers\VoucherController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('vouchers', VoucherController::class)->names('voucher');
});
