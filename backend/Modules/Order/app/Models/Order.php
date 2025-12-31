<?php

namespace Modules\Order\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Modules\Product\Models\Product;

class Order extends Model
{
    use HasFactory;

    protected $guarded = [];

    // Tạo mã đơn hàng tự động trước khi tạo
    public static function boot()
    {
        parent::boot();
        static::creating(function ($model) {
            // VD: LOU + TIMESTAMP + RANDOM NUMBER
            $model->code = 'LOU' . strtoupper(uniqid()) . rand(10, 99);
            // Hash ID để bảo mật URL
            $model->hash_id = md5($model->code . time() . rand());
        });
    }

    public function items()
    {
        return $this->hasMany(OrderItem::class);
    }
}
