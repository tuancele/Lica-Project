<?php

use Illuminate\Support\Facades\Route;
use Modules\Affiliate\Http\Controllers\AffiliateController;

Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::apiResource('affiliates', AffiliateController::class)->names('affiliate');
});
