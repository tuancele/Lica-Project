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
    // ... Giữ nguyên các hàm index, store, update, show, destroy ...
    public function index(Request $request)
    {
        $query = Coupon::withCount('products')->orderBy('created_at', 'desc');
        if ($request->q) {
            $query->where('code', 'like', "%{$request->q}%")->orWhere('name', 'like', "%{$request->q}%");
        }
        return response()->json(['status' => 200, 'data' => $query->paginate(20)]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'code' => 'required|unique:coupons,code|uppercase',
            'name' => 'required',
            'value' => 'required|numeric|min:0',
            'start_date' => 'required|date',
            'end_date' => 'required|date|after:start_date',
        ]);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        DB::beginTransaction();
        try {
            $data = $request->except('product_ids');
            $data['apply_type'] = count($request->product_ids ?? []) > 0 ? 'specific' : 'all';
            $coupon = Coupon::create($data);
            if ($request->has('product_ids')) $coupon->products()->sync($request->product_ids);
            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Tạo thành công']);
        } catch (\Exception $e) { DB::rollBack(); return response()->json(['status' => 500, 'message' => $e->getMessage()], 500); }
    }

    public function update(Request $request, $id)
    {
        $coupon = Coupon::find($id);
        if (!$coupon) return response()->json(['message' => 'Not found'], 404);
        
        $validator = Validator::make($request->all(), [
            'code' => ['required', 'uppercase', Rule::unique('coupons')->ignore($coupon->id)],
            'name' => 'required',
            'value' => 'required|numeric|min:0',
        ]);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        DB::beginTransaction();
        try {
            $data = $request->except('product_ids');
            $data['apply_type'] = count($request->product_ids ?? []) > 0 ? 'specific' : 'all';
            $coupon->update($data);
            if ($request->has('product_ids')) $coupon->products()->sync($request->product_ids);
            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Cập nhật thành công']);
        } catch (\Exception $e) { DB::rollBack(); return response()->json(['status' => 500, 'message' => $e->getMessage()], 500); }
    }

    public function show($id) {
        $coupon = Coupon::with('products:id,name,thumbnail,sku')->find($id);
        if (!$coupon) return response()->json(['message' => 'Not found'], 404);
        $coupon->product_ids = $coupon->products->pluck('id');
        return response()->json(['status' => 200, 'data' => $coupon]);
    }
    
    public function destroy($id) { Coupon::destroy($id); return response()->json(['status' => 200, 'message' => 'Deleted']); }

    // --- NEW: API Lấy Voucher khả dụng cho Checkout ---
    public function getAvailable(Request $request)
    {
        $now = now();
        // Lấy các mã: Đang hoạt động + Công khai + Trong thời gian + Còn lượt dùng
        $coupons = Coupon::where('is_active', true)
            ->where('is_public', true)
            ->where('start_date', '<=', $now)
            ->where('end_date', '>=', $now)
            ->whereColumn('used_count', '<', 'usage_limit')
            ->orderBy('value', 'desc') // Ưu tiên giảm nhiều lên đầu
            ->get();

        return response()->json(['status' => 200, 'data' => $coupons]);
    }
}
