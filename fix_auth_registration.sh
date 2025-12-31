#!/bin/bash

echo "🛠️ Đang sửa lỗi Đăng ký & Tối ưu hóa quy trình..."

# ==============================================================================
# 1. BACKEND: Cập nhật User Model (Thêm fillable)
# ==============================================================================
echo "📝 Cập nhật User Model..."
cat << 'EOF' > /var/www/lica-project/backend/app/Models/User.php
<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * The attributes that are mass assignable.
     */
    protected $fillable = [
        'name',
        'email',
        'phone',      // Thêm phone
        'username',   // Thêm username
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
}
EOF

# ==============================================================================
# 2. BACKEND: Tạo Migration để cho phép Email Null
# ==============================================================================
echo "📦 Tạo Migration sửa bảng Users..."
cat << 'EOF' > /var/www/lica-project/backend/database/migrations/2025_02_02_000002_make_email_nullable.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Cho phép email null (để đăng ký bằng SĐT)
            $table->string('email')->nullable()->change();
            // Đảm bảo name có thể null hoặc set default nếu cần (nhưng logic code sẽ tự fill)
            $table->string('name')->nullable()->change(); 
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('email')->nullable(false)->change();
        });
    }
};
EOF

# ==============================================================================
# 3. BACKEND: Cập nhật AuthController (Logic tự động)
# ==============================================================================
echo "⚙️ Cập nhật AuthController (Auto Username/Name)..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/IAM/app/Http/Controllers/AuthController.php
<?php

namespace Modules\IAM\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Modules\IAM\Models\UserAddress;
use Modules\IAM\Models\Wishlist;
use Modules\Order\Models\Order;

class AuthController extends Controller
{
    public function register(Request $request)
    {
        // 1. Chỉ validate Email/SĐT và Password
        $validator = Validator::make($request->all(), [
            'email_or_phone' => 'required|string',
            'password' => 'required|string|min:6',
        ]);

        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        $input = $request->email_or_phone;
        $isEmail = filter_var($input, FILTER_VALIDATE_EMAIL);
        $loginType = $isEmail ? 'email' : 'phone';
        
        // 2. Kiểm tra tồn tại
        if (User::where($loginType, $input)->exists()) {
            return response()->json(['status' => 422, 'message' => "Tài khoản ($input) đã tồn tại."], 422);
        }

        // 3. Tự động sinh Name và Username
        // Nếu là email: name = phần trước @, username = phần trước @ + random
        // Nếu là phone: name = phone, username = phone
        if ($isEmail) {
            $name = explode('@', $input)[0];
            $username = Str::slug($name);
        } else {
            $name = $input;
            $username = $input;
        }

        // Đảm bảo username duy nhất
        if (User::where('username', $username)->exists()) {
            $username = $username . rand(100, 999);
        }

        // 4. Tạo User
        try {
            $user = User::create([
                'name' => $name,          // Tự động
                'username' => $username,  // Tự động
                $loginType => $input,     // email hoặc phone
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
        } catch (\Exception $e) {
            return response()->json(['status' => 500, 'message' => 'Lỗi server: ' . $e->getMessage()], 500);
        }
    }

    public function login(Request $request)
    {
        $loginType = filter_var($request->email_or_phone, FILTER_VALIDATE_EMAIL) ? 'email' : 'phone';

        if (!Auth::attempt([$loginType => $request->email_or_phone, 'password' => $request->password])) {
            return response()->json(['status' => 401, 'message' => 'Tài khoản hoặc mật khẩu không đúng.'], 401);
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

    public function me(Request $request)
    {
        return response()->json(['status' => 200, 'data' => $request->user()]);
    }

    // Profile API helpers...
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
# 4. FRONTEND: Rút gọn form Đăng ký
# ==============================================================================
echo "💻 Cập nhật Frontend Register Page..."
cat << 'EOF' > /var/www/lica-project/apps/user/app/register/page.tsx
"use client";
import { useState } from "react";
import axios from "axios";
import { useRouter } from "next/navigation";
import Link from "next/link";

export default function RegisterPage() {
  const router = useRouter();
  // Form rút gọn: Chỉ cần email/sdt và password
  const [formData, setFormData] = useState({ email_or_phone: "", password: "" });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const res = await axios.post(\`\${process.env.NEXT_PUBLIC_API_URL}/api/v1/auth/register\`, formData);
      if (res.data.status === 200) {
        localStorage.setItem("token", res.data.access_token);
        localStorage.setItem("user", JSON.stringify(res.data.data));
        // Chuyển hướng đến trang profile với username tự động
        router.push(\`/profile/\${res.data.data.username}\`);
      }
    } catch (err: any) {
      console.error(err);
      setError(err.response?.data?.message || "Đăng ký thất bại. Vui lòng kiểm tra lại thông tin.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 p-4 font-sans">
      <div className="max-w-md w-full bg-white rounded-xl shadow-lg p-8">
        <h1 className="text-2xl font-bold text-center text-gray-800 mb-2">Đăng ký nhanh</h1>
        <p className="text-center text-gray-500 text-sm mb-6">Tạo tài khoản để theo dõi đơn hàng dễ dàng hơn</p>
        
        <form onSubmit={handleRegister} className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Email hoặc Số điện thoại</label>
            <input 
              type="text" 
              required 
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:ring-2 focus:ring-blue-500 transition" 
              placeholder="Ví dụ: 0912345678"
              value={formData.email_or_phone} 
              onChange={e => setFormData({...formData, email_or_phone: e.target.value})} 
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">Mật khẩu</label>
            <input 
              type="password" 
              required 
              className="w-full border border-gray-300 rounded-lg px-4 py-2.5 outline-none focus:ring-2 focus:ring-blue-500 transition" 
              placeholder="Tối thiểu 6 ký tự"
              value={formData.password} 
              onChange={e => setFormData({...formData, password: e.target.value})} 
            />
          </div>
          
          {error && <div className="p-3 bg-red-50 text-red-600 text-sm rounded-lg border border-red-100">{error}</div>}
          
          <button type="submit" disabled={loading} className="w-full bg-blue-600 text-white font-bold py-3 rounded-lg hover:bg-blue-700 transition disabled:opacity-70 shadow-sm mt-2">
            {loading ? "Đang tạo tài khoản..." : "Đăng ký ngay"}
          </button>
        </form>
        
        <div className="text-center mt-6 pt-6 border-t border-gray-100">
          <p className="text-sm text-gray-600">
            Đã có tài khoản? <Link href="/login" className="text-blue-600 font-medium hover:underline">Đăng nhập</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
EOF

# ==============================================================================
# 5. CHẠY MIGRATION & REBUILD
# ==============================================================================
echo "🔄 Chạy Migration (để sửa bảng Users)..."
cd /var/www/lica-project/backend
php artisan migrate --force

echo "🔄 Build lại Frontend User..."
cd /var/www/lica-project/apps/user
npm run build
pm2 restart lica-user

echo "✅ Đã sửa lỗi xong! Bạn có thể thử đăng ký lại."
