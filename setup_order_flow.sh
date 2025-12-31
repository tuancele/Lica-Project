#!/bin/bash

echo "🚀 Đang thiết lập luồng Đặt hàng (Checkout Flow)..."

# ==============================================================================
# 1. TẠO MIGRATION (Bảng Orders & OrderItems)
# ==============================================================================
echo "📦 Tạo bảng database cho Order..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/Order/database/migrations/2025_02_01_000000_create_full_orders_table.php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Bảng đơn hàng
        if (!Schema::hasTable('orders')) {
            Schema::create('orders', function (Blueprint $table) {
                $table->id();
                $table->string('code')->unique()->comment('Mã đơn hàng VD: LOUFOCGRD...');
                $table->string('hash_id')->unique()->comment('Mã hash cho URL success');
                
                // Thông tin khách hàng & Giao hàng
                $table->string('customer_name');
                $table->string('customer_phone');
                $table->string('customer_email')->nullable();
                $table->text('shipping_address');
                $table->text('note')->nullable();

                // Thông tin thanh toán
                $table->decimal('total_amount', 15, 2); // Tổng tiền
                $table->decimal('shipping_fee', 15, 2)->default(0); // Phí ship
                $table->string('payment_method')->default('cod'); // cod, banking
                $table->string('payment_status')->default('pending'); // pending, paid, failed
                
                $table->string('status')->default('new'); // new, processing, shipping, completed, cancelled
                
                $table->timestamps();
            });
        }

        // Bảng chi tiết đơn hàng
        if (!Schema::hasTable('order_items')) {
            Schema::create('order_items', function (Blueprint $table) {
                $table->id();
                $table->foreignId('order_id')->constrained('orders')->onDelete('cascade');
                $table->foreignId('product_id'); // Link tới bảng products
                $table->string('product_name'); // Lưu cứng tên lúc mua
                $table->string('sku')->nullable();
                $table->integer('quantity');
                $table->decimal('price', 15, 2); // Giá lúc mua
                $table->decimal('total', 15, 2); // quantity * price
                $table->json('options')->nullable(); // Size, màu (nếu có)
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('order_items');
        Schema::dropIfExists('orders');
    }
};
EOF

# ==============================================================================
# 2. TẠO MODELS (Order & OrderItem)
# ==============================================================================
echo "📝 Tạo Models..."

# Order Model
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

# OrderItem Model
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

# ==============================================================================
# 3. CẬP NHẬT CONTROLLER (Logic Đặt hàng & Success)
# ==============================================================================
echo "⚙️ Cập nhật OrderController..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/Order/app/Http/Controllers/OrderController.php
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

class OrderController extends Controller
{
    // API: POST /api/v1/order/checkout
    public function checkout(Request $request)
    {
        // 1. Validate dữ liệu
        $validator = Validator::make($request->all(), [
            'customer_name' => 'required|string',
            'customer_phone' => 'required|string',
            'shipping_address' => 'required|string',
            'payment_method' => 'required|in:cash_on_delivery,banking',
            'items' => 'required|array|min:1',
            'items.*.product_id' => 'required|exists:products,id',
            'items.*.quantity' => 'required|integer|min:1',
        ]);

        if ($validator->fails()) {
            return response()->json(['status' => 422, 'message' => 'Dữ liệu không hợp lệ', 'errors' => $validator->errors()], 422);
        }

        DB::beginTransaction();
        try {
            $input = $request->all();
            $totalAmount = 0;
            $orderItemsData = [];

            // 2. Tính toán & Kiểm tra kho
            foreach ($input['items'] as $item) {
                $product = Product::lockForUpdate()->find($item['product_id']); // Lock row để tránh race condition

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
                ];

                // 3. Trừ tồn kho
                $product->decrement('stock_quantity', $item['quantity']);
            }

            // 4. Tạo Order Master
            $order = Order::create([
                'customer_name' => $input['customer_name'],
                'customer_phone' => $input['customer_phone'],
                'customer_email' => $input['customer_email'] ?? null,
                'shipping_address' => $input['shipping_address'],
                'note' => $input['note'] ?? null,
                'total_amount' => $totalAmount,
                'shipping_fee' => 0, // Logic tính ship có thể thêm sau
                'payment_method' => $input['payment_method'],
                'status' => 'new'
            ]);

            // 5. Tạo Order Items
            foreach ($orderItemsData as $data) {
                $order->items()->create($data);
            }

            DB::commit();

            // 6. Trả về format URL success cho FE
            // FE cần: /order/success/{hash_id}?type=default&...
            return response()->json([
                'status' => 200,
                'message' => 'Đặt hàng thành công',
                'data' => [
                    'order_code' => $order->code,
                    'hash_id' => $order->hash_id,
                    'total' => $order->total_amount,
                    'redirect_url' => "/order/success/{$order->hash_id}?type=default&method={$order->payment_method}&total={$order->total_amount}"
                ]
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Checkout Error: ' . $e->getMessage());
            return response()->json(['status' => 500, 'message' => 'Lỗi server: ' . $e->getMessage()], 500);
        }
    }

    // API: GET /api/v1/order/success/{hash}
    public function getOrderByHash($hash)
    {
        $order = Order::with('items')->where('hash_id', $hash)->first();

        if (!$order) {
            return response()->json(['status' => 404, 'message' => 'Không tìm thấy đơn hàng'], 404);
        }

        return response()->json([
            'status' => 200,
            'data' => $order
        ]);
    }
}
EOF

# ==============================================================================
# 4. CẬP NHẬT ROUTE
# ==============================================================================
echo "🔗 Cập nhật Routes..."
cat << 'EOF' > /var/www/lica-project/backend/Modules/Order/routes/api.php
<?php

use Illuminate\Support\Facades\Route;
use Modules\Order\Http\Controllers\OrderController;

Route::prefix('v1/order')->group(function () {
    // API đặt hàng
    Route::post('/checkout', [OrderController::class, 'checkout']);
    
    // API lấy thông tin trang success
    Route::get('/success/{hash}', [OrderController::class, 'getOrderByHash']);
});
EOF

# ==============================================================================
# 5. CHẠY MIGRATION
# ==============================================================================
echo "🔄 Chạy Migration..."
cd /var/www/lica-project/backend
php artisan migrate --force

echo "✅ Đã thiết lập xong luồng Đặt hàng!"
