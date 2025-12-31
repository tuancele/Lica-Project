<?php

use Illuminate\Support\Facades\Route;
use Modules\APIGateway\Http\Controllers\APIGatewayController;

Route::middleware(['auth:sanctum'])->prefix('v1')->group(function () {
    Route::apiResource('apigateways', APIGatewayController::class)->names('apigateway');
});
