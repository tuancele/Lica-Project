import "./globals.css";
import Sidebar from "@/components/Sidebar";
import { Bell, HelpCircle, User } from "lucide-react";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi">
      <body className="bg-[#f6f6f6] font-sans text-gray-900">
        <Sidebar />
        
        {/* Main Content Wrapper */}
        <div className="ml-64 min-h-screen flex flex-col">
          {/* Top Header */}
          <header className="h-14 bg-white border-b flex items-center justify-between px-6 sticky top-0 z-40 shadow-sm">
            <div className="text-lg font-medium text-gray-700">Kênh Người Bán</div>
            <div className="flex items-center gap-6 text-gray-500">
              <button className="hover:text-yellow-600 flex items-center gap-1">
                <HelpCircle size={18} /> <span className="text-xs">Hỗ trợ</span>
              </button>
              <button className="hover:text-yellow-600 relative">
                <Bell size={18} />
                <span className="absolute -top-1 -right-1 w-2 h-2 bg-red-500 rounded-full"></span>
              </button>
              <div className="flex items-center gap-2 hover:bg-gray-100 p-1 rounded cursor-pointer">
                <div className="w-7 h-7 bg-yellow-100 rounded-full flex items-center justify-center text-yellow-700">
                  <User size={16} />
                </div>
                <span className="text-sm font-medium text-gray-700">Admin Lica</span>
              </div>
            </div>
          </header>

          {/* Page Content */}
          <main className="p-6 flex-1">
            {children}
          </main>
          
          <footer className="p-6 text-center text-xs text-gray-400">
            &copy; 2025 Lica Vietnam. All rights reserved.
          </footer>
        </div>
      </body>
    </html>
  );
}
