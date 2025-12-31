#!/bin/bash

BACKEND_DIR="/var/www/lica-project/backend"

echo ">>> 🚑 BẮT ĐẦU CẤP CỨU HỆ THỐNG..."

cd "$BACKEND_DIR"

# 1. XÓA CACHE BẰNG TAY (Bắt buộc vì artisan đang hỏng)
echo ">>> [1/5] Force Cleaning Cache Files..."
rm -f bootstrap/cache/packages.php
rm -f bootstrap/cache/services.php
rm -f bootstrap/cache/config.php
rm -f bootstrap/cache/routes-v7.php
rm -f storage/framework/views/*.php
echo "✅ Đã xóa cache thủ công."

# 2. CÀI ĐẶT LẠI THƯ VIỆN (Bao gồm cả dev để tránh lỗi thiếu Class)
echo ">>> [2/5] Installing Dependencies..."
# Chạy install đầy đủ để lôi Pail về (tránh lỗi thiếu class)
composer install --optimize-autoloader
# Nếu vẫn lỗi Pail, ta gỡ nó luôn
if grep -q "laravel/pail" composer.json; then
    echo "⚠️ Phát hiện Laravel Pail, đang gỡ bỏ để tránh lỗi production..."
    composer remove laravel/pail --dev --no-interaction
fi

# 3. NẠP LẠI API FIX (Do script trước chạy nửa chừng thì chết)
echo ">>> [3/5] Re-applying API Route Fix..."
PROVIDER_FILE="$BACKEND_DIR/Modules/Product/app/Providers/ProductServiceProvider.php"
cat > "$PROVIDER_FILE" <<PHP
<?php

namespace Modules\Product\Providers;

use Illuminate\Support\ServiceProvider;

class ProductServiceProvider extends ServiceProvider
{
    protected string \$moduleName = 'Product';
    protected string \$moduleNameLower = 'product';

    public function boot(): void
    {
        \$this->loadMigrationsFrom(module_path(\$this->moduleName, 'database/migrations'));
    }

    public function register(): void
    {
        \$this->app->register(RouteServiceProvider::class);
    }
}
PHP

# 4. KHỞI TẠO LẠI LARAVEL (Lúc này Artisan mới chạy được)
echo ">>> [4/5] Bootstrapping Laravel..."
php artisan package:discover --ansi
php artisan config:clear
php artisan route:clear
php artisan cache:clear

# 5. RESTART PHP-FPM (Tự động tìm đúng tên service)
echo ">>> [5/5] Restarting Services..."

# Tìm tên service PHP đang chạy (8.1, 8.2 hay 8.3)
PHP_SERVICE=$(systemctl list-units --type=service | grep -o 'php[0-9]\.[0-9]-fpm' | head -n 1)

if [ -n "$PHP_SERVICE" ]; then
    echo "🔄 Reloading $PHP_SERVICE..."
    sudo systemctl reload "$PHP_SERVICE"
else
    echo "⚠️ Không tìm thấy service PHP-FPM nào. Đang thử reload mặc định..."
    sudo service php8.3-fpm reload 2>/dev/null || sudo service php8.2-fpm reload 2>/dev/null || sudo service php8.1-fpm reload 2>/dev/null
fi

# Restart Admin
pm2 restart lica-admin 2>/dev/null

echo "--------------------------------------------------------"
echo "✅ HỆ THỐNG ĐÃ ĐƯỢC KHÔI PHỤC!"
echo "👉 Hãy F5 lại trang Admin ngay bây giờ."
echo "--------------------------------------------------------"
