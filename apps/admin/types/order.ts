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
