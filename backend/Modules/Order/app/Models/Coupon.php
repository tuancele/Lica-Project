<?php

namespace Modules\Order\Models;

use Illuminate\Database\Eloquent\Model;
use Modules\Product\Models\Product;

class Coupon extends Model
{
    protected $guarded = [];

    // Quan hệ Many-to-Many với Sản phẩm
    public function products()
    {
        return $this->belongsToMany(Product::class, 'coupon_product');
    }
}
