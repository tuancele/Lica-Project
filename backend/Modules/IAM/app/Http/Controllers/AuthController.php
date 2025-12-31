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
    // ... (Giữ nguyên các hàm register, login, me, getOrders) ...
    public function register(Request $request) {
        $validator = Validator::make($request->all(), ['email_or_phone' => 'required|string', 'password' => 'required|string|min:6']);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);
        $input = $request->email_or_phone;
        $isEmail = filter_var($input, FILTER_VALIDATE_EMAIL);
        $loginType = $isEmail ? 'email' : 'phone';
        if (User::where($loginType, $input)->exists()) return response()->json(['status' => 422, 'message' => "Tài khoản đã tồn tại."], 422);
        
        $name = $isEmail ? explode('@', $input)[0] : $input;
        $username = $input;
        if (User::where('username', $username)->exists()) $username .= rand(100,999);

        $user = User::create(['name' => $name, 'username' => $username, $loginType => $input, 'password' => Hash::make($request->password), 'membership_tier' => 'member']);
        $token = $user->createToken('auth_token')->plainTextToken;
        return response()->json(['status' => 200, 'message' => 'Đăng ký thành công', 'data' => $user, 'access_token' => $token]);
    }

    public function login(Request $request) {
        $loginType = filter_var($request->email_or_phone, FILTER_VALIDATE_EMAIL) ? 'email' : 'phone';
        if (!Auth::attempt([$loginType => $request->email_or_phone, 'password' => $request->password])) return response()->json(['status' => 401, 'message' => 'Sai tài khoản hoặc mật khẩu.'], 401);
        $user = User::where($loginType, $request->email_or_phone)->firstOrFail();
        $token = $user->createToken('auth_token')->plainTextToken;
        return response()->json(['status' => 200, 'data' => $user, 'access_token' => $token]);
    }

    public function me(Request $request) { return response()->json(['status' => 200, 'data' => $request->user()]); }
    
    public function getOrders(Request $request) {
        $orders = Order::with('items')->where('user_id', $request->user()->id)->orderBy('created_at', 'desc')->get();
        return response()->json(['status' => 200, 'data' => $orders]);
    }

    public function getAddresses(Request $request) {
        $addresses = UserAddress::where('user_id', $request->user()->id)->orderBy('is_default', 'desc')->get();
        return response()->json(['status' => 200, 'data' => $addresses]);
    }

    // UPDATE: Hàm thêm địa chỉ chuẩn
    public function addAddress(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string',
            'phone' => 'required|string',
            'province_id' => 'required',
            'district_id' => 'required',
            'ward_id' => 'required',
            'address' => 'required|string', // Địa chỉ cụ thể (Số nhà)
        ]);

        if ($validator->fails()) return response()->json(['status' => 422, 'message' => 'Dữ liệu không hợp lệ', 'errors' => $validator->errors()], 422);

        $input = $request->all();
        $input['user_id'] = $request->user()->id;
        
        // Nếu set default hoặc chưa có địa chỉ nào -> set default = true
        $count = UserAddress::where('user_id', $request->user()->id)->count();
        if ($request->is_default || $count == 0) {
            UserAddress::where('user_id', $request->user()->id)->update(['is_default' => false]);
            $input['is_default'] = true;
        }

        $addr = UserAddress::create($input);
        return response()->json(['status' => 200, 'message' => 'Thêm địa chỉ thành công', 'data' => $addr]);
    }

    public function getWishlist(Request $request) {
        $list = Wishlist::with('product')->where('user_id', $request->user()->id)->get();
        return response()->json(['status' => 200, 'data' => $list]);
    }
}
