<?php

namespace Modules\CMS\Http\Controllers;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class MediaController extends Controller
{
    public function upload(Request $request)
    {
        // 1. Validate: Chỉ cho phép ảnh, tối đa 5MB
        $request->validate([
            'file' => 'required|image|mimes:jpeg,png,jpg,gif,webp|max:5120',
        ]);

        if ($request->hasFile('file')) {
            $file = $request->file('file');
            
            // 2. Lưu file vào folder: storage/app/public/products/{yyyy-mm-dd}
            $filename = time() . '_' . $file->getClientOriginalName();
            $path = $file->storeAs('products/' . date('Y-m-d'), $filename, 'public');

            // 3. Trả về URL đầy đủ để Frontend hiển thị
            return response()->json([
                'url' => asset('storage/' . $path),
                'path' => $path
            ]);
        }

        return response()->json(['message' => 'Upload failed'], 400);
    }
}
