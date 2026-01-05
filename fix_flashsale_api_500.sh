#!/bin/bash

BACKEND_ROOT="/var/www/lica-project/backend"

echo "========================================================"
echo "   FIX LỖI 500 API FLASHSALE (MODEL & CONTROLLER)"
echo "========================================================"

# 1. Cập nhật Model ProgramItem (Quan trọng: Đảm bảo namespace đúng)
echo ">>> [1/4] Cập nhật Model ProgramItem..."
cat << 'EOF' > $BACKEND_ROOT/Modules/PriceEngine/app/Models/ProgramItem.php
<?php

namespace Modules\PriceEngine\Models;

use Illuminate\Database\Eloquent\Model;
use Modules\Product\Models\Product; // Namespace quan trọng

class ProgramItem extends Model
{
    protected $table = 'price_engine_items';
    protected $guarded = [];

    public function product()
    {
        return $this->belongsTo(Product::class, 'product_id');
    }

    public function program()
    {
        return $this->belongsTo(Program::class, 'program_id');
    }
}
EOF

# 2. Cập nhật Model Program
echo ">>> [2/4] Cập nhật Model Program..."
cat << 'EOF' > $BACKEND_ROOT/Modules/PriceEngine/app/Models/Program.php
<?php

namespace Modules\PriceEngine\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Program extends Model
{
    use HasFactory;

    protected $table = 'price_engine_programs';
    protected $guarded = [];

    protected $casts = [
        'start_at' => 'datetime',
        'end_at' => 'datetime',
        'is_active' => 'boolean',
    ];

    public function items()
    {
        return $this->hasMany(ProgramItem::class, 'program_id');
    }
}
EOF

# 3. Viết lại Controller với Try-Catch chi tiết để debug
echo ">>> [3/4] Cập nhật PriceEngineController..."
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

    // API Lấy Flash Sale Active
    public function getActiveFlashSale()
    {
        try {
            $now = now();
            
            // 1. Tìm chương trình Flash Sale đang active
            // Sử dụng Eager Loading với query con để chỉ lấy các field cần thiết (tránh lỗi memory nếu product quá lớn)
            $flashSale = Program::where('type', 'flash_sale')
                ->where('is_active', true)
                ->where('start_at', '<=', $now)
                ->where('end_at', '>=', $now)
                ->with(['items.product' => function($q) {
                    // Chỉ lấy các cột cơ bản để tránh lỗi nếu thiếu cột
                    $q->select('id', 'name', 'sku', 'price', 'images');
                }])
                ->first();

            return response()->json([
                'status' => 200, 
                'data' => $flashSale
            ]);

        } catch (\Exception $e) {
            // Log lỗi chi tiết ra laravel.log
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

# 4. Xóa cache và tối ưu lại autoload
echo ">>> [4/4] Optimize Backend..."
cd $BACKEND_ROOT
composer dump-autoload
php artisan config:clear
php artisan route:clear
php artisan cache:clear

echo "========================================================"
echo "   ĐÃ SỬA LỖI! VUI LÒNG KIỂM TRA LẠI API."
echo "========================================================"
