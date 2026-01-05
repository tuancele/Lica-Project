import api from '@/lib/axios';

export interface OrderPayload {
  customer_name: string;
  customer_phone: string;
  customer_email?: string;
  shipping_address: string;
  province_id: string | number;
  district_id: string | number;
  ward_id: string | number;
  payment_method: string;
  items: Array<{
    product_id: number;
    quantity: number;
    price: number;
  }>;
  coupon_code?: string;
  note?: string;
}

export const OrderService = {
  // Method checkout chính thức
  checkout: async (payload: OrderPayload) => {
    const res = await api.post('/order/checkout', payload);
    return res.data;
  },
  
  checkCoupon: async (code: string, total: number) => {
    const res = await api.post('/order/check-coupon', { code, total });
    return res.data;
  },
  
  getOrderByHash: async (hash: string) => {
    const res = await api.get(`/order/success/${hash}`);
    return res.data.data || res.data;
  }
};
