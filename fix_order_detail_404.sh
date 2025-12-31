#!/bin/bash

echo "🚑 Đang sửa lỗi Chi tiết đơn hàng (404 Not Found)..."

# ==============================================================================
# CẬP NHẬT ORDER CONTROLLER (Hỗ trợ tìm theo Code)
# ==============================================================================
echo "⚙️ Cập nhật Logic tìm kiếm Order..."

cat << 'EOF' > /var/www/lica-project/backend/Modules/Order/app/Http/Controllers/OrderController.php
<?php

namespace Modules\Order\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Order\Models\Order;
use Modules\Order\Models\OrderItem;
use Modules\Order\Models\Coupon;
use Modules\Product\Models\Product;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;

class OrderController extends Controller
{
    // ... Giữ nguyên các hàm calculateDiscount, checkCoupon, checkout ...
    
    private function calculateDiscount($couponCode, $cartItems)
    {
        $coupon = Coupon::where('code', $couponCode)->where('is_active', true)->first();
        if (!$coupon) return ['error' => 'Mã giảm giá không tồn tại.'];
        $now = now();
        if ($coupon->start_date && $now < $coupon->start_date) return ['error' => 'Mã chưa đến thời gian sử dụng.'];
        if ($coupon->end_date && $now > $coupon->end_date) return ['error' => 'Mã đã hết hạn sử dụng.'];
        if ($coupon->usage_limit > 0 && $coupon->used_count >= $coupon->usage_limit) return ['error' => 'Mã đã hết lượt sử dụng.'];

        $cartTotal = 0; $eligibleTotal = 0;
        $allowedProductIds = $coupon->apply_type === 'specific' ? $coupon->products->pluck('id')->toArray() : [];

        foreach ($cartItems as $item) {
            $p = Product::find($item['product_id']);
            if($p) {
                $price = $p->sale_price > 0 ? $p->sale_price : $p->price;
                $rowTotal = $price * $item['quantity'];
                $cartTotal += $rowTotal;
                if ($coupon->apply_type === 'all' || in_array($p->id, $allowedProductIds)) {
                    $eligibleTotal += $rowTotal;
                }
            }
        }

        if ($cartTotal < $coupon->min_order_value) return ['error' => 'Đơn hàng chưa đạt tối thiểu.'];
        if ($eligibleTotal == 0) return ['error' => 'Mã không áp dụng cho sản phẩm này.'];

        $discount = 0;
        if ($coupon->type === 'percent') {
            $discount = $eligibleTotal * ($coupon->value / 100);
            if ($coupon->max_discount_amount > 0 && $discount > $coupon->max_discount_amount) $discount = $coupon->max_discount_amount;
        } else {
            $discount = $coupon->value;
        }
        if ($discount > $eligibleTotal) $discount = $eligibleTotal;

        return ['discount' => $discount, 'coupon' => $coupon];
    }

    public function checkCoupon(Request $request)
    {
        $res = $this->calculateDiscount($request->code, $request->items);
        if (isset($res['error'])) return response()->json(['status' => 400, 'message' => $res['error']], 400);
        return response()->json(['status' => 200, 'data' => ['discount' => $res['discount']]]);
    }

    public function checkout(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'customer_name' => 'required', 'customer_phone' => 'required', 'shipping_address' => 'required', 'items' => 'required|array|min:1',
        ]);
        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        DB::beginTransaction();
        try {
            $input = $request->all();
            $userId = auth('sanctum')->check() ? auth('sanctum')->id() : null;
            $totalAmount = 0;
            $orderItemsData = [];

            foreach ($input['items'] as $item) {
                $product = Product::lockForUpdate()->find($item['product_id']);
                if (!$product || $product->stock_quantity < $item['quantity']) { DB::rollBack(); return response()->json(['status' => 400, 'message' => "Hết hàng."], 400); }
                
                $price = $product->sale_price > 0 ? $product->sale_price : $product->price;
                $lineTotal = $price * $item['quantity'];
                $totalAmount += $lineTotal;
                
                $orderItemsData[] = [
                    'product_id' => $product->id, 'product_name' => $product->name, 'sku' => $product->sku,
                    'quantity' => $item['quantity'], 'price' => $price, 'total' => $lineTotal,
                    'options' => json_encode($item['options'] ?? [])
                ];
                $product->decrement('stock_quantity', $item['quantity']);
            }

            $discountAmount = 0; $couponCode = null;
            if (!empty($input['coupon_code'])) {
                $couponRes = $this->calculateDiscount($input['coupon_code'], $input['items']);
                if (!isset($couponRes['error'])) {
                    $discountAmount = $couponRes['discount'];
                    $couponCode = $input['coupon_code'];
                    $couponRes['coupon']->increment('used_count');
                }
            }

            $finalTotal = max(0, $totalAmount - $discountAmount);
            
            $order = Order::create([
                'user_id' => $userId,
                'customer_name' => $input['customer_name'],
                'customer_phone' => $input['customer_phone'],
                'customer_email' => $input['customer_email'] ?? null,
                'shipping_address' => $input['shipping_address'],
                'note' => $input['note'] ?? null,
                'total_amount' => $finalTotal,
                'discount_amount' => $discountAmount,
                'coupon_code' => $couponCode,
                'payment_method' => $input['payment_method'] ?? 'cod',
                'status' => 'pending'
            ]);

            foreach ($orderItemsData as $data) { $order->items()->create($data); }
            DB::commit();

            return response()->json(['status' => 200, 'message' => 'Thành công', 'data' => ['redirect_url' => "/order/success/{$order->hash_id}"]]);

        } catch (\Exception $e) { DB::rollBack(); return response()->json(['status' => 500, 'message' => $e->getMessage()], 500); }
    }

    public function getOrderByHash($hash) { return response()->json(['status' => 200, 'data' => Order::with('items')->where('hash_id', $hash)->first()]); }
    
    public function index(Request $request) { 
        $query = Order::orderBy('created_at','desc');
        if($request->q) {
            $q = $request->q;
            $query->where(function($sub) use ($q) {
                $sub->where('code', 'like', "%{$q}%")
                    ->orWhere('customer_name', 'like', "%{$q}%")
                    ->orWhere('customer_phone', 'like', "%{$q}%");
            });
        }
        if($request->status && $request->status !== 'all') {
            $query->where('status', $request->status);
        }
        return response()->json(['status' => 200, 'data' => $query->paginate(20)]); 
    }

    // --- UPDATED SHOW METHOD: Tìm cả ID và Code ---
    public function show($id) {
        $query = Order::with('items.product');
        
        // Nếu là số -> tìm theo ID
        if (is_numeric($id)) {
            $order = $query->find($id);
        } else {
            // Nếu là chuỗi (LOU...) -> tìm theo Code
            $order = $query->where('code', $id)->first();
        }

        if (!$order) return response()->json(['message' => 'Order not found'], 404);
        
        return response()->json(['status' => 200, 'data' => $order]); 
    }
    
    public function updateStatus(Request $request, $id) {
        $order = Order::find($id);
        if(!$order) return response()->json(['message' => 'Not found'], 404);
        $order->status = $request->status;
        $order->save();
        return response()->json(['status' => 200, 'message' => 'Updated']);
    }
}
EOF

# ==============================================================================
# CLEAR CACHE
# ==============================================================================
echo "🧹 Clear Cache..."
cd /var/www/lica-project/backend
php artisan route:clear
php artisan config:clear

echo "✅ Đã sửa xong! Hãy thử tải lại trang chi tiết đơn hàng."
