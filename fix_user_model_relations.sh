#!/bin/bash

echo "🚑 Đang sửa lỗi Model User (Thiếu Relationships)..."

cd /var/www/lica-project/backend

# ==============================================================================
# CẬP NHẬT USER MODEL
# ==============================================================================
echo "📝 Cập nhật app/Models/User.php..."

cat << 'EOF' > app/Models/User.php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;
use Modules\Order\Models\Order;
use Modules\IAM\Models\UserAddress;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     */
    protected $fillable = [
        'name',
        'email',
        'phone',
        'username',
        'password',
        'membership_tier',
        'points',
        'avatar'
    ];

    /**
     * The attributes that should be hidden for serialization.
     */
    protected $hidden = [
        'password',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    // --- RELATIONSHIPS (Thêm mới) ---

    public function orders()
    {
        return $this->hasMany(Order::class, 'user_id');
    }

    public function addresses()
    {
        return $this->hasMany(UserAddress::class, 'user_id');
    }
}
EOF

# ==============================================================================
# CLEAR CACHE
# ==============================================================================
echo "🧹 Clear Cache..."
php artisan cache:clear

echo "✅ Đã sửa xong! Hãy thử truy cập lại trang chi tiết User."
