<?php

use Illuminate\Support\Facades\Route;
use Modules\Loyalty\Http\Controllers\LoyaltyController;

Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::apiResource('loyalties', LoyaltyController::class)->names('loyalty');
});
