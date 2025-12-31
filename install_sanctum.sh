#!/bin/bash

echo "🛠️ Đang cài đặt thư viện thiếu (Laravel Sanctum)..."

cd /var/www/lica-project/backend

# 1. Cài đặt Sanctum via Composer
# Dùng cờ --ignore-platform-reqs nếu server thiếu extension, nhưng thường thì không cần.
echo "📦 Running composer require laravel/sanctum..."
composer require laravel/sanctum

# 2. Publish cấu hình Sanctum (Tạo file config và migration)
echo "📝 Publishing Sanctum configuration..."
php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"

# 3. Chạy lại Migration & Seeding (Lúc nãy bị lỗi đoạn này)
echo "🔥 Reset Database (Thử lại)..."
php artisan migrate:fresh --seed --force

# 4. Clear Cache
echo "🧹 Clear Cache..."
php artisan config:clear
php artisan route:clear

# 5. Thử reload PHP-FPM (Tìm version tự động)
echo "🔄 Reloading PHP-FPM..."
PHP_VER=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;")
if systemctl list-units --full -all | grep -Fq "php$PHP_VER-fpm.service"; then
    systemctl reload "php$PHP_VER-fpm"
    echo "✅ Reloaded php$PHP_VER-fpm"
else
    echo "⚠️ Không tìm thấy service PHP-FPM tự động. Nếu code đã cập nhật mà web chưa nhận, hãy reload thủ công."
fi

echo "✅ Đã sửa xong lỗi thiếu Sanctum! Hãy thử Đăng ký lại user."
