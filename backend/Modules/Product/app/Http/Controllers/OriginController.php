<?php

namespace Modules\Product\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Modules\Product\Models\Origin;

class OriginController extends Controller
{
    public function index(Request $request)
    {
        $query = Origin::query();
        if ($request->has('q')) {
            $query->where('name', 'like', "%" . $request->q . "%");
        }
        return response()->json(['status' => 200, 'data' => $query->latest()->get()]);
    }

    public function store(Request $request)
    {
        $request->validate(['name' => 'required|string|max:255']);
        $item = Origin::create($request->all());
        return response()->json(['status' => 201, 'data' => $item]);
    }

    public function show($id)
    {
        $item = Origin::find($id);
        if (!$item) return response()->json(['message' => 'Not found'], 404);
        return response()->json(['status' => 200, 'data' => $item]);
    }

    public function update(Request $request, $id)
    {
        $item = Origin::find($id);
        if (!$item) return response()->json(['message' => 'Not found'], 404);
        $item->update($request->all());
        return response()->json(['status' => 200, 'data' => $item]);
    }

    public function destroy($id)
    {
        Origin::destroy($id);
        return response()->json(['status' => 200, 'message' => 'Deleted']);
    }
}
