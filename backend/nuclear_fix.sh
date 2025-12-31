#!/bin/bash

BACKEND_DIR="/var/www/lica-project/backend"

echo ">>> ☢️  BẮT ĐẦU QUY TRÌNH 'NUCLEAR' FIX..."

cd "$BACKEND_DIR"

# 1. Dọn dẹp thô bạo (Xóa Vendor và Cache)
echo ">>> [1/6] Deleting Vendor & Cache..."
rm -rf vendor
rm -rf bootstrap/cache/*.php
rm -rf storage/framework/views/*.php
rm -f composer.lock

# 2. Chỉnh sửa composer.json thủ công (Loại bỏ Pail)
# Dùng sed để xóa dòng chứa "laravel/pail" trong composer.json nếu có
echo ">>> [2/6] Cleaning composer.json..."
sed -i '/"laravel\/pail"/d' composer.json

# 3. Cài đặt lại thư viện (QUAN TRỌNG: --no-scripts)
# --no-scripts: Ngăn không cho Laravel khởi động khi đang cài (tránh lỗi Class not found)
echo ">>> [3/6] Re-installing Dependencies (No Scripts mode)..."
composer install --no-scripts --no-dev --optimize-autoloader

# 4. Dump Autoload (Để tạo map class mới)
echo ">>> [4/6] Dumping Autoload..."
composer dump-autoload

# 5. Fix Lỗi Module Product (Nạp lại API)
# Vì xóa vendor nên có thể các file core bị reset, ta đảm bảo file Provider này đúng
echo ">>> [5/6] Re-patching Product Module..."
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

# 6. Khởi động lại Laravel
echo ">>> [6/6] Booting Application..."
# Bây giờ mới chạy lệnh artisan, vì vendor đã sạch
php artisan package:discover --ansi
php artisan config:clear
php artisan route:clear
php artisan cache:clear

# Restart Service
echo ">>> Restarting PHP-FPM..."
sudo service php8.3-fpm reload 2>/dev/null || sudo service php8.2-fpm reload 2>/dev/null

echo "--------------------------------------------------------"
echo "✅ ĐÃ XONG! HÃY KIỂM TRA LẠI."
echo "👉 F5 Admin: https://admin.lica.vn"
echo "--------------------------------------------------------"
