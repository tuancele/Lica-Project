
// --- SYSTEM HEALTH CHECK ---
Route::get('/v1/apigateways', function () {
    try {
        \DB::connection()->getPdo();
        $dbStatus = 'connected';
        $httpCode = 200;
    } catch (\Exception $e) {
        $dbStatus = 'error';
        $httpCode = 500;
    }

    return response()->json([
        'status' => $httpCode,
        'message' => 'Lica Gateway Online',
        'database' => $dbStatus,
        'timestamp' => now()->toDateTimeString()
    ], $httpCode);
});
