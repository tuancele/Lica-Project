#!/bin/bash

echo "🛠️ Đang sửa lỗi thiếu thư mục Models..."

# 1. Tạo thư mục Models nếu chưa có
mkdir -p /var/www/lica-project/backend/Modules/Order/app/Models

# 2. Tạo lại Order Model
echo "📝 Tạo file Order.php..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/Order/app/Models/Order.php
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
EOF

# 3. Tạo lại OrderItem Model
echo "📝 Tạo file OrderItem.php..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/Order/app/Models/OrderItem.php
<?php

namespace Modules\Order\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Modules\Product\Models\Product;

class OrderItem extends Model
{
    use HasFactory;

    protected $guarded = [];

    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}
EOF

echo "✅ Đã khôi phục xong Models cho Order!"
