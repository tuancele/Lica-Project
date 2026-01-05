import Link from "next/link";

const LINKS = [
  { title: "Bán Chạy", icon: "🔥", href: "#" },
  { title: "Giao 2H", icon: "🚀", href: "#" },
  { title: "Hàng Hiệu", icon: "💎", href: "#" },
  { title: "Clinic & Spa", icon: "🏥", href: "#" },
  { title: "Combo Tiết Kiệm", icon: "🎁", href: "#" },
  { title: "Soi Da", icon: "🔍", href: "#" },
  { title: "Đặt Hẹn", icon: "📅", href: "#" },
  { title: "Cẩm Nang", icon: "📖", href: "#" },
];

export default function QuickLinks() {
  return (
    <div className="bg-white py-6 border-b border-gray-100 mb-4">
      <div className="container-custom">
        <div className="grid grid-cols-4 md:grid-cols-8 gap-4">
          {LINKS.map((link, idx) => (
            <Link key={idx} href={link.href} className="flex flex-col items-center gap-2 group cursor-pointer">
              <div className="w-12 h-12 rounded-2xl bg-gray-50 flex items-center justify-center text-2xl group-hover:bg-lica-primary/10 group-hover:scale-110 transition-all duration-300 shadow-sm border border-gray-100">
                {link.icon}
              </div>
              <span className="text-[11px] md:text-xs font-semibold text-gray-700 text-center group-hover:text-lica-primary">
                {link.title}
              </span>
            </Link>
          ))}
        </div>
      </div>
    </div>
  );
}
