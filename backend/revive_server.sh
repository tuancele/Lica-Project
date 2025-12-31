#!/bin/bash

BACKEND_DIR="/var/www/lica-project/backend"
ADMIN_DIR="/var/www/lica-project/apps/admin"

echo ">>> BẮT ĐẦU KHẮC PHỤC SỰ CỐ SAU KHI RESET..."

# ====================================================
# 1. FIX LỖI 500 (DO QUYỀN TRUY CẬP & KEY)
# ====================================================
echo ">>> [1/4] Fixing Permissions & Environment..."
cd "$BACKEND_DIR"

# Cấp quyền tối đa cho thư mục log/cache (Quan trọng!)
chmod -R 777 storage bootstrap/cache

# Kiểm tra App Key (Nếu thiếu sẽ gây lỗi 500)
if ! grep -q "APP_KEY=base64" .env; then
    echo ">>> Generating App Key..."
    php artisan key:generate --force
fi

# ====================================================
# 2. FIX LỖI CORS (CHẶN KẾT NỐI TỪ ADMIN)
# ====================================================
echo ">>> [2/4] Configuring CORS..."
cat > "$BACKEND_DIR/config/cors.php" <<PHP
<?php
return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],
    'allowed_methods' => ['*'],
    'allowed_origins' => ['*'], // Mở toàn bộ để Admin truy cập được
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
PHP

# ====================================================
# 3. FIX LỖI MẤT API (DO CODE GIT THIẾU ĐĂNG KÝ)
# ====================================================
echo ">>> [3/4] Re-applying API Route Fix..."
# Code trên Git của bạn quên đăng ký RouteServiceProvider trong module Product
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
        // QUAN TRỌNG: Dòng này bị thiếu trên GitHub, phải thêm vào mới có API
        \$this->app->register(RouteServiceProvider::class);
    }
}
PHP

# ====================================================
# 4. FIX LỖI FRONTEND & KHỞI ĐỘNG LẠI
# ====================================================
echo ">>> [4/4] Restarting System..."

# Clear Cache Backend
cd "$BACKEND_DIR"
php artisan config:clear
php artisan route:clear
php artisan cache:clear
composer dump-autoload

# Kiểm tra xem API sống chưa
echo ">>> Testing API..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://api.lica.vn/api/v1/product)
if [ "$HTTP_CODE" == "200" ]; then
    echo "✅ API is ALIVE (Status: 200)"
else
    echo "⚠️ API Status: $HTTP_CODE (Nếu 500 thì kiểm tra log bên dưới)"
fi

# Restart Services
sudo service php8.2-fpm reload
pm2 restart lica-admin 2>/dev/null

# Hiển thị 20 dòng log lỗi cuối cùng (nếu có) để debug
if [ "$HTTP_CODE" == "500" ]; then
    echo "❌ Vẫn còn lỗi 500. Log chi tiết:"
    tail -n 20 "$BACKEND_DIR/storage/logs/laravel.log"
fi

echo "--------------------------------------------------------"
echo "✅ ĐÃ XONG! HÃY F5 LẠI TRANG ADMIN."
echo "--------------------------------------------------------"
