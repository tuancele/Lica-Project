<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Promotion;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class PromotionController extends Controller
{
    public function index(Request $request)
    {
        $query = Promotion::withCount('products')->orderBy('created_at', 'desc');
        if ($request->q) {
            $query->where('name', 'like', "%{$request->q}%");
        }
        return response()->json(['status' => 200, 'data' => $query->paginate(20)]);
    }

    public function store(Request $request)
    {
        return $this->savePromotion($request);
    }

    public function update(Request $request, $id)
    {
        return $this->savePromotion($request, $id);
    }

    // Hàm chung xử lý Lưu/Cập nhật để tránh lặp code
    private function savePromotion($request, $id = null)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required',
            'start_date' => 'required|date',
            'end_date' => 'required|date|after:start_date',
            'products' => 'required|array|min:1'
        ]);

        if ($validator->fails()) return response()->json(['status' => 422, 'errors' => $validator->errors()], 422);

        DB::beginTransaction();
        try {
            $data = [
                'name' => $request->name,
                'start_date' => $request->start_date,
                'end_date' => $request->end_date,
                'is_active' => true
            ];

            if ($id) {
                $promotion = Promotion::find($id);
                if (!$promotion) return response()->json(['message' => 'Not found'], 404);
                $promotion->update($data);
            } else {
                $promotion = Promotion::create($data);
            }

            // Xử lý Pivot Data
            $syncData = [];
            foreach ($request->products as $p) {
                $originalPrice = $p['original_price'];
                $discountValue = $p['discount_value'];
                $finalPrice = 0;

                if ($p['discount_type'] === 'percent') {
                    $finalPrice = $originalPrice * (1 - ($discountValue / 100));
                } else {
                    $finalPrice = $originalPrice - $discountValue;
                }

                $syncData[$p['product_id']] = [
                    'discount_type' => $p['discount_type'],
                    'discount_value' => $discountValue,
                    'final_price' => max(0, $finalPrice),
                    'stock_limit' => $p['stock_limit'] ?? 0
                ];
                
                // Cập nhật giá sale_price trực tiếp vào bảng products để các tính năng khác (Cart, Order) dùng luôn
                // Lưu ý: Đây là cách đơn giản nhất. Cách phức tạp hơn là Query Scope.
                DB::table('products')->where('id', $p['product_id'])->update(['sale_price' => max(0, $finalPrice)]);
            }

            // Sync: Tự động xóa các sản phẩm không còn trong danh sách và cập nhật sản phẩm có
            $promotion->products()->sync($syncData);

            // Nếu update: Cần reset sale_price của các sản phẩm bị loại bỏ khỏi chương trình về 0
            // (Phần này nâng cao, tạm thời ta chấp nhận cập nhật đè khi có chương trình mới)

            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Lưu chương trình thành công']);
        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }

    public function show($id)
    {
        $promotion = Promotion::with(['products' => function($q) {
            $q->select('products.id', 'products.name', 'products.thumbnail', 'products.price as original_price', 'products.sku');
        }])->find($id);
        
        if (!$promotion) return response()->json(['message' => 'Not found'], 404);
        return response()->json(['status' => 200, 'data' => $promotion]);
    }

    public function destroy($id)
    {
        $promotion = Promotion::find($id);
        if ($promotion) {
            // Reset giá sale của các sản phẩm trong chương trình về 0
            $productIds = $promotion->products->pluck('id');
            DB::table('products')->whereIn('id', $productIds)->update(['sale_price' => 0]);
            
            $promotion->delete();
        }
        return response()->json(['status' => 200, 'message' => 'Đã xóa']);
    }
}
