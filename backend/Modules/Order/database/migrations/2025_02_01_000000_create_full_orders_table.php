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
