<?php

use Illuminate\Support\Facades\Route;
use Modules\SkinAnalysis\Http\Controllers\SkinAnalysisController;

Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::apiResource('skinanalyses', SkinAnalysisController::class)->names('skinanalysis');
});
