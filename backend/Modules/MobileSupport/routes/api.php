<?php

use Illuminate\Support\Facades\Route;
use Modules\MobileSupport\Http\Controllers\MobileSupportController;

Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::apiResource('mobilesupports', MobileSupportController::class)->names('mobilesupport');
});
