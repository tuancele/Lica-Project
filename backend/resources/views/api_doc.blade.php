<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Lica API Documentation</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700&display=swap" rel="stylesheet">
    <style>body { font-family: 'Inter', sans-serif; }</style>
</head>
<body class="bg-gray-50 text-gray-800">

    <div class="max-w-7xl mx-auto p-6">
        <div class="flex items-center justify-between mb-8 bg-white p-6 rounded-xl shadow-sm border border-gray-100">
            <div>
                <h1 class="text-3xl font-bold text-yellow-600">LICA.VN API</h1>
                <p class="text-gray-500 mt-1">Danh sách các điểm truy cập (Endpoints) của hệ thống</p>
            </div>
            <div class="text-right">
                <div class="text-sm font-bold text-gray-600">Backend Server</div>
                <div class="text-xs text-green-600">● Online</div>
            </div>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
            <table class="w-full text-left border-collapse">
                <thead class="bg-gray-100 text-gray-600 text-xs uppercase">
                    <tr>
                        <th class="p-4 border-b">Method</th>
                        <th class="p-4 border-b">Endpoint (URI)</th>
                        <th class="p-4 border-b">Mô tả / Tên Route</th>
                        <th class="p-4 border-b text-right">Hành động</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-100 text-sm">
                    @foreach($routes as $route)
                        @php
                            $methodColor = match($route['method']) {
                                'GET' => 'bg-blue-100 text-blue-700 border-blue-200',
                                'POST' => 'bg-green-100 text-green-700 border-green-200',
                                'PUT' => 'bg-orange-100 text-orange-700 border-orange-200',
                                'DELETE' => 'bg-red-100 text-red-700 border-red-200',
                                default => 'bg-gray-100 text-gray-700',
                            };
                        @endphp
                        <tr class="hover:bg-gray-50 transition">
                            <td class="p-4 w-24">
                                <span class="px-3 py-1 rounded-md text-xs font-bold border {{ $methodColor }}">
                                    {{ $route['method'] }}
                                </span>
                            </td>
                            <td class="p-4 font-mono text-gray-700">
                                /{{ $route['uri'] }}
                            </td>
                            <td class="p-4 text-gray-500">
                                {{ $route['name'] ?? '---' }}
                                <div class="text-[10px] text-gray-400 mt-1">{{ $route['action'] }}</div>
                            </td>
                            <td class="p-4 text-right">
                                @if($route['method'] == 'GET' && !str_contains($route['uri'], '{'))
                                    <a href="/{{ $route['uri'] }}" target="_blank" class="text-blue-600 hover:underline text-xs">
                                        Chạy thử ↗
                                    </a>
                                @else
                                    <span class="text-gray-300 text-xs">Cần tham số</span>
                                @endif
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
            
            @if(count($routes) == 0)
                <div class="p-10 text-center text-gray-500">Chưa có API nào được đăng ký.</div>
            @endif
        </div>
        
        <div class="mt-6 text-center text-xs text-gray-400">
            Powered by Laravel v{{ Illuminate\Foundation\Application::VERSION }}
        </div>
    </div>

</body>
</html>
