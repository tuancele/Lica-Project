<?php

namespace Modules\Product\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Product extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected $casts = [
        'images' => 'array',
        'skin_type_ids' => 'array',
        'is_active' => 'boolean',
    ];

    public function category() {
        return $this->belongsTo(Category::class);
    }

    public function brand() {
        return $this->belongsTo(Brand::class);
    }

    public function origin() {
        return $this->belongsTo(Origin::class);
    }

    public function unit() {
        return $this->belongsTo(Unit::class);
    }
}
