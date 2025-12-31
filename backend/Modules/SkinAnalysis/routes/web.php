<?php

use Illuminate\Support\Facades\Route;
use Modules\SkinAnalysis\Http\Controllers\SkinAnalysisController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('skinanalyses', SkinAnalysisController::class)->names('skinanalysis');
});
