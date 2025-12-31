export interface Brand {
  id: number;
  name: string;
  slug: string;
  logo?: string;
}

export interface Origin {
  id: number;
  name: string;
  code?: string;
}

export interface Unit {
  id: number;
  name: string;
}

export interface SkinType {
  id: number;
  name: string;
  code?: string;
}

export interface Category {
  id: number;
  name: string;
  slug: string;
  parent_id: number | null;
  level: number;
}

export interface Product {
  id: number;
  name: string;
  slug: string;
  sku: string | null;
  price: string | number;
  sale_price: string | number | null;
  stock_quantity: number;
  thumbnail: string | null;
  images: string[] | null;
  
  // Vận chuyển
  weight: number;
  length: number;
  width: number;
  height: number;
  
  // Nội dung
  short_description: string | null;
  description: string | null;
  ingredients: string | null;
  usage_instructions: string | null;

  // Quan hệ (Master Data)
  category_id: number | null;
  brand_id: number | null;
  origin_id: number | null;
  unit_id: number | null;
  skin_type_ids: number[] | null; // Mảng ID loại da

  // Để hiển thị (Optional)
  brand?: Brand;
  origin?: Origin;
  unit?: Unit;
  category?: Category;
  
  is_active: boolean;
}
