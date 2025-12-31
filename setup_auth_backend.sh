#!/bin/bash

echo "🚀 Đang thiết lập hệ thống Xác thực & Profile..."

# ==============================================================================
# 1. MIGRATION: Cập nhật Users & Tạo bảng phụ
# ==============================================================================
echo "📦 Tạo Migrations..."

cat << 'EOF' > /var/www/lica-project/backend/database/migrations/2025_02_02_000001_update_users_and_create_profiles.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Update Users table
        if (Schema::hasTable('users')) {
            Schema::table('users', function (Blueprint $table) {
                if (!Schema::hasColumn('users', 'phone')) {
                    $table->string('phone')->nullable()->unique()->after('email');
                }
                if (!Schema::hasColumn('users', 'avatar')) {
                    $table->string('avatar')->nullable();
                }
                if (!Schema::hasColumn('users', 'username')) {
                    $table->string('username')->nullable()->unique(); // Cho URL /profile/tuancele
                }
                if (!Schema::hasColumn('users', 'membership_tier')) {
                    $table->string('membership_tier')->default('member'); // member, silver, gold, diamond
                }
                if (!Schema::hasColumn('users', 'points')) {
                    $table->integer('points')->default(0);
                }
            });
        }

        // 2. Add user_id to Orders
        if (Schema::hasTable('orders')) {
            Schema::table('orders', function (Blueprint $table) {
                if (!Schema::hasColumn('orders', 'user_id')) {
                    $table->foreignId('user_id')->nullable()->constrained('users')->onDelete('set null');
                }
            });
        }

        // 3. User Addresses (Sổ địa chỉ)
        if (!Schema::hasTable('user_addresses')) {
            Schema::create('user_addresses', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained()->onDelete('cascade');
                $table->string('name'); // Tên người nhận
                $table->string('phone');
                $table->text('address');
                $table->string('province_id')->nullable();
                $table->string('district_id')->nullable();
                $table->string('ward_id')->nullable();
                $table->boolean('is_default')->default(false);
                $table->timestamps();
            });
        }

        // 4. Wishlists (Sản phẩm yêu thích)
        if (!Schema::hasTable('wishlists')) {
            Schema::create('wishlists', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained()->onDelete('cascade');
                $table->foreignId('product_id')->constrained()->onDelete('cascade');
                $table->timestamps();
                $table->unique(['user_id', 'product_id']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('wishlists');
        Schema::dropIfExists('user_addresses');
    }
};
EOF

# ==============================================================================
# 2. MODELS: Address & Wishlist
# ==============================================================================
echo "📝 Tạo Models..."

mkdir -p /var/www/lica-project/backend/Modules/IAM/app/Models

cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Models/UserAddress.php
<?php

namespace Modules\IAM\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class UserAddress extends Model
{
    use HasFactory;
    protected $guarded = [];
}
EOF

cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Models/Wishlist.php
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
EOF

# ==============================================================================
# 3. CONTROLLER: AuthController & ProfileController
# ==============================================================================
echo "⚙️ Tạo AuthController..."

cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Http/Controllers/AuthController.php
<?php

namespace Modules\IAM\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Modules\IAM\Models\UserAddress;
use Modules\IAM\Models\Wishlist;
use Modules\Order\Models\Order;

class AuthController extends Controller
{
    // Đăng ký (Email hoặc Phone)
    public function register(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'username' => 'required|string|max:50|unique:users',
            'email_or_phone' => 'required|string',
            'password' => 'required|string|min:6',
        ]);

        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        $loginType = filter_var($request->email_or_phone, FILTER_VALIDATE_EMAIL) ? 'email' : 'phone';
        
        // Check exist
        if (User::where($loginType, $request->email_or_phone)->exists()) {
            return response()->json(['status' => 422, 'message' => "$loginType đã tồn tại."], 422);
        }

        $user = User::create([
            'name' => $request->name,
            'username' => $request->username,
            $loginType => $request->email_or_phone,
            'password' => Hash::make($request->password),
            'membership_tier' => 'member'
        ]);

        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'status' => 200,
            'message' => 'Đăng ký thành công',
            'data' => $user,
            'access_token' => $token
        ]);
    }

    // Đăng nhập
    public function login(Request $request)
    {
        $loginType = filter_var($request->email_or_phone, FILTER_VALIDATE_EMAIL) ? 'email' : 'phone';

        if (!Auth::attempt([$loginType => $request->email_or_phone, 'password' => $request->password])) {
            return response()->json(['status' => 401, 'message' => 'Thông tin đăng nhập không chính xác.'], 401);
        }

        $user = User::where($loginType, $request->email_or_phone)->firstOrFail();
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'status' => 200,
            'message' => 'Đăng nhập thành công',
            'data' => $user,
            'access_token' => $token
        ]);
    }

    // Lấy thông tin user (Profile)
    public function me(Request $request)
    {
        return response()->json(['status' => 200, 'data' => $request->user()]);
    }

    // ================= PROFILE SECTIONS =================

    public function getOrders(Request $request)
    {
        $orders = Order::with('items')->where('user_id', $request->user()->id)->orderBy('created_at', 'desc')->get();
        return response()->json(['status' => 200, 'data' => $orders]);
    }

    public function getAddresses(Request $request)
    {
        $addresses = UserAddress::where('user_id', $request->user()->id)->get();
        return response()->json(['status' => 200, 'data' => $addresses]);
    }

    public function addAddress(Request $request)
    {
        $input = $request->all();
        $input['user_id'] = $request->user()->id;
        
        // Nếu là địa chỉ đầu tiên hoặc set default -> bỏ default cũ
        if ($request->is_default || UserAddress::where('user_id', $request->user()->id)->count() == 0) {
            UserAddress::where('user_id', $request->user()->id)->update(['is_default' => false]);
            $input['is_default'] = true;
        }

        $addr = UserAddress::create($input);
        return response()->json(['status' => 200, 'data' => $addr]);
    }

    public function getWishlist(Request $request)
    {
        $list = Wishlist::with('product')->where('user_id', $request->user()->id)->get();
        return response()->json(['status' => 200, 'data' => $list]);
    }
}
EOF

# ==============================================================================
# 4. ROUTE API
# ==============================================================================
echo "🔗 Cập nhật Route API..."

cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/routes/api.php
<?php

use Illuminate\Support\Facades\Route;
use Modules\IAM\Http\Controllers\AuthController;

Route::prefix('v1/auth')->group(function () {
    Route::post('/register', [AuthController::class, 'register']);
    Route::post('/login', [AuthController::class, 'login']);
});

Route::middleware(['auth:sanctum'])->prefix('v1/profile')->group(function () {
    Route::get('/me', [AuthController::class, 'me']);
    Route::get('/orders', [AuthController::class, 'getOrders']);
    Route::get('/addresses', [AuthController::class, 'getAddresses']);
    Route::post('/addresses', [AuthController::class, 'addAddress']);
    Route::get('/wishlist', [AuthController::class, 'getWishlist']);
});
EOF

# ==============================================================================
# 5. CHẠY MIGRATION
# ==============================================================================
echo "🔄 Chạy Migration..."
cd /var/www/lica-project/backend
php artisan migrate --force

echo "✅ Backend Auth Setup Completed!"
