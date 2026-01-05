<?php

use Illuminate\Support\Facades\Route;
use Modules\PriceEngine\Http\Controllers\PriceEngineController;

Route::prefix('v1/marketing/promotions')->group(function () {
    Route::get('/flash-sale/active', [PriceEngineController::class, 'getActiveFlashSale']); // Route mới
    
    Route::get('/', [PriceEngineController::class, 'index']);
    Route::post('/', [PriceEngineController::class, 'store']);
    Route::get('/{id}', [PriceEngineController::class, 'show']);
    Route::put('/{id}', [PriceEngineController::class, 'update']);
    Route::delete('/{id}', [PriceEngineController::class, 'destroy']);
});
