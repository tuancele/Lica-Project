<?php

use Illuminate\Support\Facades\Route;
use Modules\Review\Http\Controllers\ReviewController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('reviews', ReviewController::class)->names('review');
});
