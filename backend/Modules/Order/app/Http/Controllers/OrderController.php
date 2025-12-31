<?php

namespace Modules\Order\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Order\Models\Order;
use Modules\Order\Models\OrderItem;
use Modules\Product\Models\Product;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Auth;

class OrderController extends Controller
{
    // ================= CLIENT API =================

    public function checkout(Request $request)
    {
        // 1. Log request để debug
        Log::info('Checkout Request Data:', $request->all());

        $validator = Validator::make($request->all(), [
            'customer_name' => 'required|string',
            'customer_phone' => 'required|string',
            'shipping_address' => 'required|string',
            'items' => 'required|array|min:1',
        ]);

        if ($validator->fails()) {
            Log::warning('Checkout Validation Failed:', $validator->errors()->toArray());
            return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);
        }

        DB::beginTransaction();
        try {
            $input = $request->all();
            
            // 2. Lấy User ID nếu có (Dùng Guard Sanctum)
            $userId = null;
            if (auth('sanctum')->check()) {
                $userId = auth('sanctum')->id();
            }

            $totalAmount = 0;
            $orderItemsData = [];

            foreach ($input['items'] as $item) {
                // Lock row để tránh race condition
                $product = Product::lockForUpdate()->find($item['product_id']);
                
                if (!$product) {
                    DB::rollBack();
                    return response()->json(['status' => 400, 'message' => "Sản phẩm ID {$item['product_id']} không tồn tại."], 400);
                }

                if ($product->stock_quantity < $item['quantity']) {
                    DB::rollBack();
                    return response()->json(['status' => 400, 'message' => "Sản phẩm {$product->name} không đủ hàng tồn kho."], 400);
                }

                $price = $product->sale_price > 0 ? $product->sale_price : $product->price;
                $lineTotal = $price * $item['quantity'];
                $totalAmount += $lineTotal;

                $orderItemsData[] = [
                    'product_id' => $product->id,
                    'product_name' => $product->name,
                    'sku' => $product->sku,
                    'quantity' => $item['quantity'],
                    'price' => $price,
                    'total' => $lineTotal,
                    'options' => json_encode($item['options'] ?? [])
                ];

                // Trừ tồn kho
                $product->decrement('stock_quantity', $item['quantity']);
            }

            // 3. Tạo Order (Thêm user_id)
            $order = Order::create([
                'user_id' => $userId, // <--- QUAN TRỌNG: Lưu ID người dùng
                'customer_name' => $input['customer_name'],
                'customer_phone' => $input['customer_phone'],
                'customer_email' => $input['customer_email'] ?? null,
                'shipping_address' => $input['shipping_address'],
                'note' => $input['note'] ?? null,
                'total_amount' => $totalAmount,
                'payment_method' => $input['payment_method'] ?? 'cod',
                'status' => 'pending'
            ]);

            foreach ($orderItemsData as $data) {
                $order->items()->create($data);
            }

            DB::commit();

            return response()->json([
                'status' => 200,
                'message' => 'Đặt hàng thành công',
                'data' => [
                    'order_code' => $order->code,
                    'hash_id' => $order->hash_id,
                    'redirect_url' => "/order/success/{$order->hash_id}"
                ]
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            // Ghi log lỗi chi tiết ra file storage/logs/laravel.log
            Log::error('Checkout Error 500: ' . $e->getMessage());
            Log::error($e->getTraceAsString());
            
            return response()->json(['status' => 500, 'message' => 'Lỗi hệ thống: ' . $e->getMessage()], 500);
        }
    }

    public function getOrderByHash($hash)
    {
        $order = Order::with('items')->where('hash_id', $hash)->first();
        return $order ? response()->json(['status' => 200, 'data' => $order]) : response()->json(['status' => 404], 404);
    }

    // ================= ADMIN API =================

    public function index(Request $request)
    {
        $query = Order::with('items.product')->orderBy('created_at', 'desc');

        if ($request->has('status') && $request->status !== 'all') {
            $query->where('status', $request->status);
        }

        if ($request->has('q') && !empty($request->q)) {
            $q = $request->q;
            $query->where(function($sub) use ($q) {
                $sub->where('code', 'like', "%{$q}%")
                    ->orWhere('customer_name', 'like', "%{$q}%")
                    ->orWhere('customer_phone', 'like', "%{$q}%");
            });
        }

        $data = $query->paginate($request->get('limit', 10));
        
        $counts = Order::select('status', DB::raw('count(*) as total'))
            ->groupBy('status')
            ->pluck('total', 'status')
            ->toArray();

        return response()->json([
            'status' => 200,
            'data' => $data,
            'counts' => $counts
        ]);
    }

    public function show($id)
    {
        $query = Order::with('items.product');
        if (is_numeric($id)) {
            $order = $query->find($id);
            if (!$order) $order = $query->where('code', $id)->first();
        } else {
            $order = $query->where('code', $id)->first();
        }

        return $order 
            ? response()->json(['status' => 200, 'data' => $order]) 
            : response()->json(['message' => 'Không tìm thấy đơn hàng'], 404);
    }

    public function updateStatus(Request $request, $id)
    {
        $order = is_numeric($id) ? Order::find($id) : Order::where('code', $id)->first();
        if (!$order) return response()->json(['message' => 'Not found'], 404);

        $newStatus = $request->status;
        $order->status = $newStatus;
        if ($newStatus === 'completed') $order->payment_status = 'paid';
        $order->save();

        return response()->json(['status' => 200, 'message' => 'Cập nhật trạng thái thành công', 'data' => $order]);
    }
}
