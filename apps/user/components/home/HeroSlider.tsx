import { ChevronRight, ChevronLeft } from 'lucide-react';

export default function HeroSlider() {
  return (
    <div className="bg-gray-100 py-3">
        <div className="container-custom">
            <div className="grid grid-cols-1 md:grid-cols-12 gap-3">
                {/* Main Slider (Chiếm 8 phần) */}
                <div className="md:col-span-8 relative group rounded-xl overflow-hidden shadow-sm h-[200px] md:h-[320px] bg-white">
                    {/* Placeholder cho Slider Image */}
                    <div className="w-full h-full bg-gradient-to-r from-teal-50 to-green-50 flex items-center justify-center">
                        <div className="text-center">
                            <h2 className="text-3xl font-bold text-lica-primary mb-2">ĐẠI TIỆC SALES</h2>
                            <p className="text-gray-500">Giảm giá lên đến 50% toàn bộ sản phẩm</p>
                        </div>
                    </div>
                    
                    {/* Navigation Buttons (Fake) */}
                    <button className="absolute left-2 top-1/2 -translate-y-1/2 bg-white/50 p-2 rounded-full hover:bg-white text-gray-700 opacity-0 group-hover:opacity-100 transition-opacity">
                        <ChevronLeft className="w-6 h-6" />
                    </button>
                    <button className="absolute right-2 top-1/2 -translate-y-1/2 bg-white/50 p-2 rounded-full hover:bg-white text-gray-700 opacity-0 group-hover:opacity-100 transition-opacity">
                        <ChevronRight className="w-6 h-6" />
                    </button>
                </div>

                {/* Right Banners (Chiếm 4 phần) */}
                <div className="md:col-span-4 hidden md:flex flex-col gap-3 h-[320px]">
                    <div className="flex-1 bg-white rounded-xl overflow-hidden shadow-sm flex items-center justify-center bg-gradient-to-br from-blue-50 to-indigo-50">
                        <span className="text-lica-secondary font-bold">Giao nhanh 2H</span>
                    </div>
                    <div className="flex-1 bg-white rounded-xl overflow-hidden shadow-sm flex items-center justify-center bg-gradient-to-br from-orange-50 to-red-50">
                        <span className="text-lica-red font-bold">Voucher 100K</span>
                    </div>
                </div>
            </div>
        </div>
    </div>
  );
}
