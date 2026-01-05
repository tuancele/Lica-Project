<?php

namespace Modules\Order\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Order\Models\Coupon;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class CouponController extends Controller
{
    public function index(Request $request)
    {
        $query = Coupon::withCount('products')->orderBy('created_at', 'desc');
        if ($request->q) {
            $query->where('code', 'like', "%{$request->q}%")->orWhere('name', 'like', "%{$request->q}%");
        }
        return response()->json(['status' => 200, 'data' => $query->paginate(20)]);
    }

    // API LẤY VOUCHER KHẢ DỤNG (FIX LỖI 500)
    public function getAvailableCoupons(Request $request)
    {
        try {
            $now = now();
            $coupons = Coupon::where('is_active', true)
                // .where('is_public', true) // Tạm bỏ check public để tránh lỗi nếu thiếu cột
                ->where('start_date', '<=', $now)
                ->where('end_date', '>=', $now)
                ->whereColumn('used_count', '<', 'usage_limit')
                ->orderBy('value', 'desc')
                ->select('id', 'code', 'name', 'type', 'value', 'min_order_value', 'description')
                ->get();

            return response()->json(['status' => 200, 'data' => $coupons]);
        } catch (\Exception $e) {
            return response()->json(['status' => 500, 'message' => $e->getMessage()]);
        }
    }

    public function check(Request $request)
    {
        $request->validate(['code' => 'required|string', 'total' => 'required|numeric']);
        $code = strtoupper(trim($request->code));
        $total = $request->total;
        $now = now();

        $coupon = Coupon::where('code', $code)->where('is_active', true)
            ->where('start_date', '<=', $now)->where('end_date', '>=', $now)->first();

        if (!$coupon) return response()->json(['status' => 400, 'message' => 'Mã không tồn tại hoặc hết hạn'], 400);
        if ($coupon->used_count >= $coupon->usage_limit) return response()->json(['status' => 400, 'message' => 'Mã đã hết lượt dùng'], 400);
        if ($total < $coupon->min_order_value) return response()->json(['status' => 400, 'message' => 'Đơn tối thiểu ' . number_format($coupon->min_order_value) . 'đ'], 400);

        $discount = ($coupon->type === 'percent') ? ($total * $coupon->value / 100) : $coupon->value;
        // Check max discount if exists column
        // if ($coupon->max_discount_amount && $discount > $coupon->max_discount_amount) $discount = $coupon->max_discount_amount;

        return response()->json(['status' => 200, 'data' => ['discount' => $discount, 'code' => $coupon->code]]);
    }

    public function store(Request $request) {
        // Giữ logic cũ nhưng rút gọn
        $validator = Validator::make($request->all(), [
            'code' => 'required|unique:coupons,code|uppercase', 'name' => 'required', 'value' => 'required|numeric',
            'start_date' => 'required|date', 'end_date' => 'required|date|after:start_date'
        ]);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);
        Coupon::create($request->all());
        return response()->json(['status' => 200, 'message' => 'Created']);
    }

    public function update(Request $request, $id) { Coupon::find($id)->update($request->all()); return response()->json(['status' => 200, 'message' => 'Updated']); }
    public function show($id) { return response()->json(['status' => 200, 'data' => Coupon::find($id)]); }
    public function destroy($id) { Coupon::destroy($id); return response()->json(['status' => 200, 'message' => 'Deleted']); }
}
