<?php

use Illuminate\Support\Facades\Route;
use Modules\QRVerification\Http\Controllers\QRVerificationController;

Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::apiResource('qrverifications', QRVerificationController::class)->names('qrverification');
});
