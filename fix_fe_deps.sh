#!/bin/bash

echo "🛠️ Đang cài đặt thư viện thiếu (lucide-react) cho User App..."

# Vào thư mục User App
cd /var/www/lica-project/apps/user

# Cài đặt thư viện icon
npm install lucide-react

echo "🔄 Đang build lại User App..."
npm run build
pm2 restart lica-user

echo "✅ Đã sửa lỗi xong! Hãy thử truy cập lại."
