<?php

use Illuminate\Support\Facades\Route;
use Modules\PriceEngine\Http\Controllers\PriceEngineController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('priceengines', PriceEngineController::class)->names('priceengine');
});
