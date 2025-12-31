#!/bin/bash

echo "🛠️ Đang sửa lỗi thiếu Type customer_email..."

# Cập nhật file types/order.ts
cat << 'EOF' > /var/www/lica-project/apps/admin/types/order.ts
export interface OrderItem {
  id: number;
  product_name: string;
  sku: string;
  quantity: number;
  price: number;
  total: number;
  product?: { thumbnail: string };
}

export interface Order {
  id: number;
  code: string;
  customer_name: string;
  customer_phone: string;
  customer_email?: string; // Đã thêm trường này (optional)
  shipping_address: string;
  total_amount: number;
  payment_method: string;
  status: 'pending' | 'processing' | 'shipping' | 'completed' | 'cancelled' | 'returned';
  created_at: string;
  items: OrderItem[];
}

export type OrderStatus = Order['status'] | 'all';
EOF

echo "🔄 Đang build lại Admin App..."
cd /var/www/lica-project/apps/admin
npm run build
pm2 restart lica-admin

echo "✅ Đã sửa lỗi xong! Bạn có thể xem chi tiết đơn hàng ngay."
