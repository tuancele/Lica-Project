<?php

return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],
    'allowed_methods' => ['*'],
    
    // Thay vì '*', hãy chỉ định rõ domain để tránh lỗi khi kèm credentials
    'allowed_origins' => [
        'https://lica.vn',
        'https://admin.lica.vn',
        'https://api.lica.vn',
        'http://localhost:3000',
        'http://localhost:3001'
    ],
    
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    
    // Bật lên để hỗ trợ cookie/session nếu cần sau này
    'supports_credentials' => true,
];
