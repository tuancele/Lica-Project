<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\Route;

class ApiDocController extends Controller
{
    public function index()
    {
        $routes = Route::getRoutes();
        $apiRoutes = [];

        foreach ($routes as $route) {
            // Chỉ lấy các route bắt đầu bằng 'api'
            if (str_contains($route->uri(), 'api/')) {
                $methods = $route->methods();
                // Loại bỏ method HEAD
                if (($key = array_search('HEAD', $methods)) !== false) {
                    unset($methods[$key]);
                }
                
                $apiRoutes[] = [
                    'method' => implode('|', $methods),
                    'uri' => $route->uri(),
                    'name' => $route->getName(),
                    'action' => $route->getActionName(),
                ];
            }
        }

        return view('api_doc', ['routes' => $apiRoutes]);
    }
}
