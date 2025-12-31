<?php

use Illuminate\Support\Facades\Route;
use Modules\Affiliate\Http\Controllers\AffiliateController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('affiliates', AffiliateController::class)->names('affiliate');
});
