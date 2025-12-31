<?php

use Illuminate\Support\Facades\Route;
use Modules\APIGateway\Http\Controllers\APIGatewayController;

Route::middleware(['auth', 'verified'])->group(function () {
    Route::resource('apigateways', APIGatewayController::class)->names('apigateway');
});
