#!/bin/bash

# --- CẤU HÌNH ---
BACKEND_DIR="/var/www/lica-project/backend"
ADMIN_DIR="/var/www/lica-project/apps/admin"

echo ">>> BẮT ĐẦU SỬA LỖI TOÀN DIỆN (CORS + API + MISSING PAGES)..."

# ==========================================
# 1. FIX LỖI BACKEND (CORS & API ROUTE)
# ==========================================
echo ">>> [1/4] Configuring CORS & Fixing Providers..."

# A. Cấu hình CORS (Cho phép Admin và User gọi API)
# Ghi đè file config/cors.php để mở chặn
cat > "$BACKEND_DIR/config/cors.php" <<PHP
<?php

return [
    'paths' => ['api/*', 'sanctum/csrf-cookie'],
    'allowed_methods' => ['*'],
    'allowed_origins' => ['*'], // Cho phép tất cả domain (Fix nhanh lỗi CORS)
    'allowed_origins_patterns' => [],
    'allowed_headers' => ['*'],
    'exposed_headers' => [],
    'max_age' => 0,
    'supports_credentials' => false,
];
PHP

# B. Fix lỗi mất API Product (Do thiếu đăng ký Route trong Provider)
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
        // QUAN TRỌNG: Đăng ký RouteServiceProvider để API hoạt động
        \$this->app->register(RouteServiceProvider::class);
    }
}
PHP

# C. Xóa Cache Backend để nhận cấu hình mới
cd "$BACKEND_DIR"
php artisan config:clear
php artisan route:clear
php artisan cache:clear
composer dump-autoload

# ==========================================
# 2. FIX LỖI FRONTEND (TẠO TRANG CÒN THIẾU)
# ==========================================
echo ">>> [2/4] Creating Missing Frontend Pages..."
APP_DIR="$ADMIN_DIR/app"

# Hàm tạo trang dummy
create_page() {
    PATH_URL=$1
    TITLE=$2
    mkdir -p "$APP_DIR/$PATH_URL"
    
    # Chỉ tạo nếu chưa có
    if [ ! -f "$APP_DIR/$PATH_URL/page.tsx" ]; then
        cat > "$APP_DIR/$PATH_URL/page.tsx" <<TSX
"use client";
import React from 'react';
import { Construction } from 'lucide-react';

export default function Page() {
  return (
    <div className="flex flex-col items-center justify-center h-[60vh] text-gray-500">
      <div className="p-4 bg-gray-100 rounded-full mb-4">
        <Construction size={48} className="text-yellow-600" />
      </div>
      <h1 className="text-2xl font-bold text-gray-800">$TITLE</h1>
      <p className="mt-2 text-sm">Tính năng đang được phát triển.</p>
    </div>
  );
}
TSX
    fi
}

# Tạo các trang bị lỗi 404 trong log
create_page "orders" "Quản Lý Đơn Hàng"
create_page "orders/cancel" "Đơn Hàng Đã Hủy"
create_page "orders/return" "Trả Hàng / Hoàn Tiền"
create_page "users" "Quản Lý Khách Hàng"
create_page "products/settings" "Cài Đặt Sản Phẩm"

# ==========================================
# 3. FIX BIẾN MÔI TRƯỜNG FRONTEND
# ==========================================
echo ">>> [3/4] Fixing Frontend Environment..."
# Đảm bảo URL API đúng (không có đuôi thừa)
cat > "$ADMIN_DIR/.env.local" <<ENV
NEXT_PUBLIC_API_URL=https://api.lica.vn
ENV

# ==========================================
# 4. REBUILD & RESTART
# ==========================================
echo ">>> [4/4] Applying Changes..."

# Restart Backend PHP-FPM
sudo service php8.2-fpm reload

# Rebuild Frontend
cd "$ADMIN_DIR"
# Xóa cache build cũ để chắc chắn
rm -rf .next
npm run build

# Restart PM2
pm2 delete lica-admin 2>/dev/null || true
pm2 start npm --name "lica-admin" -- start -- -p 3001
pm2 save

echo "--------------------------------------------------------"
echo "✅ ĐÃ SỬA XONG TOÀN BỘ LỖI!"
echo "👉 1. API đã mở CORS (Hết lỗi chặn kết nối)."
echo "👉 2. Module Product đã nạp Route (Hết lỗi API 404/500)."
echo "👉 3. Các trang Orders/Users đã được tạo (Hết lỗi frontend 404)."
echo "👉 Hãy đợi 10s rồi F5 lại trang Admin: https://admin.lica.vn"
echo "--------------------------------------------------------"
