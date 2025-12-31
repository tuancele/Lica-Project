<?php

namespace Modules\IAM\Models;

use Illuminate\Database\Eloquent\Model;
use Modules\Product\Models\Product;

class Wishlist extends Model
{
    protected $guarded = [];
    public function product() {
        return $this->belongsTo(Product::class);
    }
}
