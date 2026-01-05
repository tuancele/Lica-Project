<?php

namespace Modules\Product\Models;

use Illuminate\Database\Eloquent\Model;
use Modules\Product\Models\Product;

class Promotion extends Model
{
    protected $guarded = [];

    public function products()
    {
        return $this->belongsToMany(Product::class, 'promotion_product')
                    ->withPivot('discount_type', 'discount_value', 'final_price', 'stock_limit');
    }
}
