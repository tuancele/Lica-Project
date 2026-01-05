import Header from "@/components/layout/Header";
import Navigation from "@/components/layout/Navigation";
import Footer from "@/components/layout/Footer";
import HeroSlider from "@/components/home/HeroSlider";
import QuickLinks from "@/components/home/QuickLinks";
import FlashSale from "@/components/home/FlashSale";

export default function Home() {
  return (
    <div className="min-h-screen flex flex-col font-sans bg-gray-50">
      <Header />
      <Navigation />
      
      <main className="flex-1 pb-10">
        <HeroSlider />
        <QuickLinks />

        <div className="container-custom">
          {/* Flash Sale Section */}
          <FlashSale />

          {/* Banner quảng cáo nhỏ */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 my-6">
             <div className="h-[140px] bg-blue-100 rounded-xl overflow-hidden relative group cursor-pointer">
                <div className="absolute inset-0 bg-blue-200/50 group-hover:bg-transparent transition-all"></div>
                <div className="absolute bottom-4 left-4 font-bold text-blue-800">Dưỡng da <br/>mùa hanh khô</div>
             </div>
             <div className="h-[140px] bg-pink-100 rounded-xl overflow-hidden relative group cursor-pointer">
                <div className="absolute inset-0 bg-pink-200/50 group-hover:bg-transparent transition-all"></div>
                <div className="absolute bottom-4 left-4 font-bold text-pink-800">Son môi <br/>chính hãng</div>
             </div>
             <div className="h-[140px] bg-green-100 rounded-xl overflow-hidden relative group cursor-pointer">
                <div className="absolute inset-0 bg-green-200/50 group-hover:bg-transparent transition-all"></div>
                <div className="absolute bottom-4 left-4 font-bold text-green-800">Thực phẩm <br/>chức năng</div>
             </div>
          </div>
        </div>
      </main>

      <Footer />
    </div>
  );
}
