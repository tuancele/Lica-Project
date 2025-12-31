<?php
namespace Modules\Voucher\Http\Controllers;
use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Voucher\Models\Voucher;

class VoucherController extends Controller {
    public function index() {
        return response()->json(Voucher::all());
    }
    public function store(Request $request) {
        $data = $request->validate(['code' => 'required|unique:vouchers', 'discount_amount' => 'required|numeric']);
        return response()->json(Voucher::create($data), 201);
    }
}
