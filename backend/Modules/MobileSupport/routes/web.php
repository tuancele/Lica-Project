<?php

use Illuminate\Support\Facades\Route;
use Modules\MobileSupport\Http\Controllers\MobileSupportController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('mobilesupports', MobileSupportController::class)->names('mobilesupport');
});
