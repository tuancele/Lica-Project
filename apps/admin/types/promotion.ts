export interface PromotionItem {
  id?: number;
  product_id: number;
  promotion_price: number;
  stock_limit?: number;
  product?: {
    id: number;
    name: string;
    sku: string;
    price: number;
    images: string | string[];
  };
}

export interface Promotion {
  id: number;
  name: string;
  start_at: string;
  end_at: string;
  is_active: boolean;
  items_count?: number;
  items?: PromotionItem[];
}
