<?php

use Illuminate\Support\Facades\Route;
use Modules\QRManagement\Http\Controllers\QRManagementController;

Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::apiResource('qrmanagements', QRManagementController::class)->names('qrmanagement');
});
