import api from '@/lib/axios';

// Interface Category (Đã bị thiếu)
export interface Category {
  id: number;
  name: string;
  slug?: string;
  image?: string;
}

export interface DiscountInfo {
    type: 'flash_sale' | 'promotion';
    price: number;
    program_name: string;
    end_at: string;
}

export interface Product {
  id: number;
  name: string;
  sku: string;
  price: number;
  sale_price?: number;
  images: string[] | string; 
  rating?: number;
  reviews_count?: number;
  discount_info?: DiscountInfo;
  has_discount?: boolean;
  description?: string;
  category?: Category;
}

export const ProductService = {
  getProducts: async (params?: any) => {
    try {
      const res = await api.get('/product', { params });
      return res.data.data ? res.data.data : (res.data || []);
    } catch (error) {
      console.error("Lỗi lấy SP:", error);
      return [];
    }
  },

  getActiveFlashSale: async () => {
    try {
        const res = await api.get('/marketing/promotions/flash-sale/active');
        return res.data.data; 
    } catch (error) {
        return null;
    }
  },
  
  getProductDetail: async (id: string | number) => {
    try {
        const res = await api.get(`/product/${id}`);
        return res.data.data ? res.data.data : res.data;
    } catch (error) {
        return null;
    }
  },

  getCategories: async () => {
    try {
      const res = await api.get('/category');
      return res.data.data ? res.data.data : [];
    } catch { return []; }
  }
};
