<?php

use Illuminate\Support\Facades\Route;
use Modules\QRVerification\Http\Controllers\QRVerificationController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('qrverifications', QRVerificationController::class)->names('qrverification');
});
