<?php

namespace Modules\IAM\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\User;
use Illuminate\Support\Facades\DB;

class UserController extends Controller
{
    public function index(Request $request)
    {
        $query = User::query()->orderBy('created_at', 'desc');

        if ($request->has('q') && !empty($request->q)) {
            $q = $request->q;
            $query->where(function($sub) use ($q) {
                $sub->where('name', 'like', "%{$q}%")
                    ->orWhere('email', 'like', "%{$q}%")
                    ->orWhere('phone', 'like', "%{$q}%")
                    ->orWhere('username', 'like', "%{$q}%");
            });
        }

        $users = $query->paginate($request->get('limit', 20));

        return response()->json(['status' => 200, 'data' => $users]);
    }

    public function show($id)
    {
        // Load User kèm Địa chỉ và Đơn hàng (sắp xếp đơn mới nhất)
        $user = User::with(['addresses', 'orders' => function($q) {
            $q->orderBy('created_at', 'desc');
        }])->find($id);

        if (!$user) return response()->json(['message' => 'User not found'], 404);

        // --- PHÂN TÍCH SỐ LIỆU ---
        
        // 1. Tổng chi tiêu (Chỉ tính đơn đã hoàn thành)
        $totalSpent = $user->orders->where('status', 'completed')->sum('total_amount');
        
        // 2. Thống kê số lượng đơn
        $totalOrders = $user->orders->count();
        $completedOrders = $user->orders->where('status', 'completed')->count();
        $cancelledOrders = $user->orders->where('status', 'cancelled')->count();

        // 3. Giá trị trung bình đơn hàng (AOV)
        $aov = $completedOrders > 0 ? $totalSpent / $completedOrders : 0;

        // Gắn thêm dữ liệu vào response
        $user->analytics = [
            'total_spent' => $totalSpent,
            'total_orders' => $totalOrders,
            'completed_orders' => $completedOrders,
            'cancelled_orders' => $cancelledOrders,
            'aov' => $aov // Average Order Value
        ];

        return response()->json(['status' => 200, 'data' => $user]);
    }

    public function destroy($id)
    {
        if ($id == 1) return response()->json(['message' => 'Cannot delete Super Admin'], 403);
        $user = User::find($id);
        if (!$user) return response()->json(['message' => 'User not found'], 404);
        $user->delete();
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
