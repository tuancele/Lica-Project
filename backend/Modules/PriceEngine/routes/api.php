<?php

use Illuminate\Support\Facades\Route;
use Modules\PriceEngine\Http\Controllers\PriceEngineController;

Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::apiResource('priceengines', PriceEngineController::class)->names('priceengine');
});
