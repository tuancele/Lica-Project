<?php

namespace Modules\Product\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Modules\PriceEngine\Models\ProgramItem;

class Product extends Model
{
    use HasFactory;

    protected $guarded = [];

    protected $casts = [
        'images' => 'array',
        'skin_type_ids' => 'array',
        'is_active' => 'boolean',
        'dimensions' => 'array',
    ];

    protected $appends = ['sale_price', 'has_discount', 'discount_info'];

    public function category() { return $this->belongsTo(Category::class); }
    public function brand() { return $this->belongsTo(Brand::class); }
    public function origin() { return $this->belongsTo(Origin::class); }
    public function unit() { return $this->belongsTo(Unit::class); }

    /**
     * Lấy TẤT CẢ chương trình giảm giá ĐANG CHẠY cho sản phẩm này
     */
    public function activeDiscounts()
    {
        return $this->hasMany(ProgramItem::class)
            ->whereHas('program', function ($query) {
                $now = now();
                $query->where('is_active', true)
                      ->where('start_at', '<=', $now)
                      ->where('end_at', '>=', $now);
            })
            ->with('program'); // Eager load program để check type
    }

    /**
     * Tính toán thông tin giảm giá dựa trên độ ưu tiên
     */
    public function getDiscountInfoAttribute()
    {
        if (!$this->relationLoaded('activeDiscounts')) {
            // Fallback nếu chưa eager load (chỉ dùng khi gọi lẻ)
            $discounts = $this->activeDiscounts()->get();
        } else {
            $discounts = $this->activeDiscounts;
        }

        if ($discounts->isEmpty()) {
            return null;
        }

        // 1. Ưu tiên Flash Sale
        $flashSale = $discounts->first(function ($item) {
            return $item->program->type === 'flash_sale';
        });

        if ($flashSale) {
            return [
                'type' => 'flash_sale',
                'price' => $flashSale->promotion_price,
                'program_name' => $flashSale->program->name,
                'end_at' => $flashSale->program->end_at
            ];
        }

        // 2. Tiếp đến là Promotion thường
        $promotion = $discounts->first(function ($item) {
            return $item->program->type === 'promotion';
        });

        if ($promotion) {
            return [
                'type' => 'promotion',
                'price' => $promotion->promotion_price,
                'program_name' => $promotion->program->name,
                'end_at' => $promotion->program->end_at
            ];
        }

        return null;
    }

    public function getSalePriceAttribute()
    {
        $info = $this->discount_info;
        return $info ? $info['price'] : $this->price;
    }

    public function getHasDiscountAttribute()
    {
        return $this->sale_price < $this->price;
    }
}
