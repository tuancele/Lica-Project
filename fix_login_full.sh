#!/bin/bash

echo "🛠️ Đang sửa lỗi Login/Register (CORS & Database)..."

# ==============================================================================
# 1. CẤU HÌNH LẠI CORS (Chuẩn Production)
# ==============================================================================
echo "📝 Cập nhật config/cors.php..."
cat << 'EOF' > /var/www/lica-project/backend/config/cors.php
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
EOF

# ==============================================================================
# 2. KIỂM TRA & SỬA QUYỀN GHI LOG (Quan trọng để debug)
# ==============================================================================
echo "🔑 Cấp quyền ghi cho thư mục Logs & Cache..."
chown -R www-data:www-data /var/www/lica-project/backend/storage
chmod -R 775 /var/www/lica-project/backend/storage

# ==============================================================================
# 3. RESET DATABASE (Khắc phục lỗi "email cannot be null")
# ==============================================================================
echo "🔥 Reset Database (Migrate Fresh)..."
# Lưu ý: Lệnh này sẽ xóa dữ liệu cũ để tạo lại bảng với cấu trúc đúng (email nullable)
cd /var/www/lica-project/backend
php artisan migrate:fresh --seed --force

# ==============================================================================
# 4. CLEAR CACHE
# ==============================================================================
echo "🧹 Xóa Cache hệ thống..."
php artisan optimize:clear
php artisan config:clear
php artisan route:clear

# ==============================================================================
# 5. RESTART SERVICES
# ==============================================================================
echo "🔄 Khởi động lại PHP-FPM & Queue..."
# Restart php-fpm (tùy phiên bản, ở đây thử reload service phổ biến)
systemctl reload php8.2-fpm || systemctl reload php8.1-fpm || echo "⚠️ Không tìm thấy service PHP-FPM, vui lòng restart thủ công nếu cần."

echo "✅ Đã sửa xong! Hãy thử Đăng ký lại."
