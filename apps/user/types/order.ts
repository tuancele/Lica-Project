export interface OrderItemInput {
  product_id: number;
  quantity: number;
}

export interface CheckoutPayload {
  customer_name: string;
  customer_phone: string;
  customer_email: string;
  shipping_address: string;
  payment_method: string;
  items: OrderItemInput[];
}

export interface OrderSuccessData {
  id: number;
  code: string;
  customer_name: string;
  total_amount: string;
  payment_method: string;
  items: any[];
}
