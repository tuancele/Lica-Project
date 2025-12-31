export interface Product {
  id: number;
  name: string;
  slug: string;
  sku: string | null;
  price: string;
  sale_price: string | null;
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
  
  // --- MỚI: Đặc tính mỹ phẩm ---
  ingredients: string | null;
  usage_instructions: string | null;
  skin_type: string | null;
  capacity: string | null;
  // -----------------------------

  brand: string | null;
  category_id: number | null;
  category?: { id: number, name: string };
  is_active: boolean;
}

export interface Category {
  id: number;
  name: string;
  slug: string;
  parent_id: number | null;
  level: number;
}
