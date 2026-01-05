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
  items: Array<{ product_id: number; quantity: number; price: number; }>;
  coupon_code?: string;
  discount_amount?: number;
  note?: string;
}

export interface Coupon {
    id: number;
    code: string;
    title: string;
    type: 'fixed' | 'percent';
    value: number;
    min_order_value: number;
    description?: string;
}

export const OrderService = {
  checkout: async (payload: OrderPayload) => {
    const res = await api.post('/order/checkout', payload);
    return res.data;
  },
  
  // API lấy voucher khả dụng
  getAvailableCoupons: async () => {
    try {
        const res = await api.get('/marketing/coupons/available');
        return res.data.data || [];
    } catch { return []; }
  },

  // API kiểm tra voucher
  checkCoupon: async (code: string, total: number) => {
    const res = await api.post('/order/check-coupon', { code, total });
    return res.data; // Trả về { status: 200, data: { discount: ... } } hoặc lỗi
  },
  
  getOrderByHash: async (hash: string) => {
    const res = await api.get(`/order/success/${hash}`);
    return res.data.data || res.data;
  }
};
