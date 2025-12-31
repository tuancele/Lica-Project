import "./globals.css";
import Sidebar from "@/components/layout/Sidebar";

export const metadata = {
  title: "Lica Admin Portal",
  description: "Hệ thống quản trị Lica.vn",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi">
      <body className="bg-gray-50">
        <div className="flex">
            <Sidebar />
            <main className="flex-1 ml-64 min-h-screen">
                {children}
            </main>
        </div>
      </body>
    </html>
  );
}
