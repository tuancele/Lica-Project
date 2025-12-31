<?php

use Illuminate\Support\Facades\Route;
use Modules\QRManagement\Http\Controllers\QRManagementController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('qrmanagements', QRManagementController::class)->names('qrmanagement');
});
