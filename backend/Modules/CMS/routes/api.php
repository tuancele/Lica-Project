<?php

use Illuminate\Support\Facades\Route;
use Modules\CMS\Http\Controllers\MediaController;

Route::prefix('v1/cms')->group(function () {
    Route::post('/upload', [MediaController::class, 'upload']);
});
