<?php

return [
    // Thêm 'marketing/*' và '*' để đảm bảo không bị chặn dù URL có prefix api hay không
    'paths' => ['api/*', 'sanctum/csrf-cookie', 'marketing/*', '*'],
    'allowed_methods' => ['*'],
    'allowed_origins' => ['*'], // Chấp nhận mọi domain (Admin, User, Localhost)
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => true,
];
