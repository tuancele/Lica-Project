<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ApiDocController;

// Khi truy cập trang chủ API, hiển thị danh sách
Route::get('/', [ApiDocController::class, 'index']);
