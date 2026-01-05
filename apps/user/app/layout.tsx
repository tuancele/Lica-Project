import type { Metadata } from "next";
import "./globals.css";
import { CartProvider } from "@/context/CartContext";

export const metadata: Metadata = {
  title: "Lica.vn - Mỹ phẩm & Clinic",
  description: "Hệ thống mỹ phẩm chính hãng và dịch vụ Clinic uy tín.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="vi">
      <body>
        <CartProvider>
            {children}
        </CartProvider>
      </body>
    </html>
  );
}
