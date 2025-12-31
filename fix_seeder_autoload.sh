#!/bin/bash

echo "🛠️ Đang sửa lỗi Autoload cho Seeder..."

cd /var/www/lica-project/backend

# 1. Dùng PHP để thêm dòng map namespace vào composer.json một cách an toàn
php -r "
\$file = 'composer.json';
\$json = json_decode(file_get_contents(\$file), true);

// Thêm mapping cho namespace Seeder của Module IAM
\$json['autoload']['psr-4']['Modules\\\\IAM\\\\Database\\\\Seeders\\\\'] = 'Modules/IAM/database/seeders/';

file_put_contents(\$file, json_encode(\$json, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));
"

# 2. Cập nhật lại Autoload của Composer
echo "🔄 Chạy composer dump-autoload..."
composer dump-autoload

# 3. Chạy lại lệnh Seeder bị lỗi trước đó
echo "🌱 Đang Import dữ liệu Tỉnh/Thành..."
php artisan db:seed --class="Modules\\IAM\\Database\\Seeders\\VietnamLocationsSeeder"

echo "✅ Đã sửa lỗi và Import thành công!"
