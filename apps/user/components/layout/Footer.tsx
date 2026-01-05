export default function Footer() {
  return (
    <footer className="bg-white border-t border-gray-200 mt-10 pt-10 pb-6 text-xs text-gray-600">
      <div className="container-custom">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8 mb-8">
            <div>
                <h3 className="font-bold text-gray-800 uppercase mb-4">Hỗ trợ khách hàng</h3>
                <ul className="space-y-2">
                    <li>Hotline: <span className="font-bold text-lica-primary">1800 1234</span> (Miễn phí)</li>
                    <li>Các câu hỏi thường gặp</li>
                    <li>Gửi yêu cầu hỗ trợ</li>
                    <li>Hướng dẫn đặt hàng</li>
                    <li>Phương thức vận chuyển</li>
                </ul>
            </div>
            <div>
                <h3 className="font-bold text-gray-800 uppercase mb-4">Về Lica.vn</h3>
                <ul className="space-y-2">
                    <li>Giới thiệu Lica.vn</li>
                    <li>Tuyển dụng</li>
                    <li>Chính sách bảo mật</li>
                    <li>Điều khoản sử dụng</li>
                    <li>Liên hệ</li>
                </ul>
            </div>
            <div>
                <h3 className="font-bold text-gray-800 uppercase mb-4">Hợp tác & Liên kết</h3>
                <ul className="space-y-2">
                    <li>Lica Clinic</li>
                    <li>Cẩm nang làm đẹp</li>
                </ul>
            </div>
            <div>
                <h3 className="font-bold text-gray-800 uppercase mb-4">Thanh toán</h3>
                <div className="flex gap-2 flex-wrap">
                    <div className="w-10 h-6 bg-gray-200 rounded"></div>
                    <div className="w-10 h-6 bg-gray-200 rounded"></div>
                    <div className="w-10 h-6 bg-gray-200 rounded"></div>
                </div>
            </div>
        </div>
        <div className="text-center pt-6 border-t border-gray-100">
            <p className="mb-2">© 2025 Lica.vn - Hệ thống mỹ phẩm chính hãng & Clinic.</p>
            <p>Công ty TNHH Lica Beauty. Địa chỉ: ...</p>
        </div>
      </div>
    </footer>
  );
}
