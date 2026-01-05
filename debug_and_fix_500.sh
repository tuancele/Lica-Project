#!/bin/bash

BACKEND_ROOT="/var/www/lica-project/backend"
LOG_FILE="$BACKEND_ROOT/storage/logs/laravel.log"

echo "========================================================"
echo "   SỬA LỖI 500 API FLASHSALE & KIỂM TRA LOG"
echo "========================================================"

# 1. Cập nhật lại Controller (Bỏ select để load full model, tránh lỗi Appends)
echo ">>> [1/4] Cập nhật PriceEngineController (Safe Query)..."
cat << 'EOF' > $BACKEND_ROOT/Modules/PriceEngine/app/Http/Controllers/PriceEngineController.php
<?php

namespace Modules\PriceEngine\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\PriceEngine\Models\Program;
use Modules\PriceEngine\Models\ProgramItem;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class PriceEngineController extends Controller
{
    public function index(Request $request)
    {
        $query = Program::withCount('items')->orderBy('id', 'desc');
        if ($request->has('type')) {
            $query->where('type', $request->type);
        }
        return response()->json(['status' => 200, 'data' => $query->paginate(20)]);
    }

    public function getActiveFlashSale()
    {
        try {
            $now = now();
            
            // Tìm chương trình Flash Sale đang active
            $flashSale = Program::where('type', 'flash_sale')
                ->where('is_active', true)
                ->where('start_at', '<=', $now)
                ->where('end_at', '>=', $now)
                ->with(['items.product']) // Load full product để đảm bảo appends hoạt động
                ->first();

            return response()->json([
                'status' => 200, 
                'data' => $flashSale
            ]);

        } catch (\Exception $e) {
            Log::error("FlashSale API Error: " . $e->getMessage());
            Log::error($e->getTraceAsString());
            
            return response()->json([
                'status' => 500, 
                'message' => 'Lỗi Server: ' . $e->getMessage()
            ], 500);
        }
    }

    public function store(Request $request) { return $this->saveProgram($request); }
    public function update(Request $request, $id) { return $this->saveProgram($request, $id); }

    private function saveProgram(Request $request, $id = null)
    {
        $request->validate([
            'name' => 'required|string',
            'start_at' => 'required|date',
            'end_at' => 'required|date|after:start_at',
            'products' => 'required|array|min:1',
        ]);

        DB::beginTransaction();
        try {
            $data = [
                'name' => $request->name,
                'start_at' => $request->start_at,
                'end_at' => $request->end_at,
                'type' => $request->type ?? 'promotion',
                'is_active' => true
            ];

            if ($id) {
                $program = Program::findOrFail($id);
                $program->update($data);
                $program->items()->delete();
            } else {
                $program = Program::create($data);
            }

            $itemsData = [];
            foreach ($request->products as $item) {
                if(!isset($item['id'])) continue;
                $itemsData[] = [
                    'program_id' => $program->id,
                    'product_id' => $item['id'],
                    'promotion_price' => $item['promotion_price'] ?? 0,
                    'stock_limit' => !empty($item['stock_limit']) ? $item['stock_limit'] : null,
                    'created_at' => now(),
                    'updated_at' => now(),
                ];
            }
            if(!empty($itemsData)) ProgramItem::insert($itemsData);

            DB::commit();
            return response()->json(['status' => 200, 'message' => 'Thành công', 'data' => $program]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json(['status' => 500, 'message' => $e->getMessage()], 500);
        }
    }

    public function show($id)
    {
        $program = Program::with('items.product')->find($id);
        return $program ? response()->json(['status' => 200, 'data' => $program]) : response()->json(['message' => 'Not found'], 404);
    }

    public function destroy($id)
    {
        Program::destroy($id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
EOF

# 2. Sửa quyền & Xóa cache
echo ">>> [2/4] Fix permissions & Clear cache..."
cd $BACKEND_ROOT
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache
php artisan config:clear
php artisan route:clear
php artisan cache:clear
composer dump-autoload

# 3. Hiển thị Log lỗi gần nhất (để bạn biết nguyên nhân nếu vẫn lỗi)
echo ">>> [3/4] TRÍCH XUẤT ERROR LOG MỚI NHẤT:"
echo "--------------------------------------------------------"
if [ -f "$LOG_FILE" ]; then
    # Tìm dòng chứa "local.ERROR" gần nhất và in ra 10 dòng sau đó
    grep -A 10 "local.ERROR" $LOG_FILE | tail -n 20
else
    echo "Không tìm thấy file log tại $LOG_FILE"
fi
echo "--------------------------------------------------------"

echo "========================================================"
echo "   ĐÃ SỬA XONG! VUI LÒNG KIỂM TRA LẠI WEBSITE."
echo "========================================================"
