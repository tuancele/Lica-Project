<?php

namespace Modules\Product\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Product extends Model
{
    use HasFactory;

    protected $fillable = [
        'name', 'slug', 'sku', 'brand', 'category_id', // Đổi category -> category_id
        'price', 'sale_price', 'stock_quantity',
        'weight', 'length', 'width', 'height',
        'short_description', 'description', 'ingredients', 'usage_instructions', 'skin_type', 'capacity',
        'thumbnail', 'images',
        'is_active', 'is_featured'
    ];

    protected $casts = [
        'images' => 'array',
        'is_active' => 'boolean',
        'is_featured' => 'boolean',
        'price' => 'decimal:2',
        'sale_price' => 'decimal:2',
        'weight' => 'integer',
    ];

    public function category()
    {
        return $this->belongsTo(Category::class);
    }
}
