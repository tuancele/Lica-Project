<?php

use Illuminate\Support\Facades\Route;
use Modules\Loyalty\Http\Controllers\LoyaltyController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('loyalties', LoyaltyController::class)->names('loyalty');
});
