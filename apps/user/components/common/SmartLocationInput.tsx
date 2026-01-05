'use client';

import { useState, useEffect } from 'react';
import { LocationService, LocationOption } from '@/services/location.service';

interface LocationData {
  province?: LocationOption;
  district?: LocationOption;
  ward?: LocationOption;
  fullAddress: string;
}

interface Props {
  // Tên prop chuẩn dùng cho toàn bộ dự án
  onLocationChange: (data: LocationData) => void;
}

export default function SmartLocationInput({ onLocationChange }: Props) {
  const [provinces, setProvinces] = useState<LocationOption[]>([]);
  const [districts, setDistricts] = useState<LocationOption[]>([]);
  const [wards, setWards] = useState<LocationOption[]>([]);

  const [selectedProvince, setSelectedProvince] = useState<string>('');
  const [selectedDistrict, setSelectedDistrict] = useState<string>('');
  const [selectedWard, setSelectedWard] = useState<string>('');
  const [street, setStreet] = useState('');

  useEffect(() => {
    LocationService.getProvinces().then(setProvinces);
  }, []);

  useEffect(() => {
    if (selectedProvince) {
      setDistricts([]); setWards([]); setSelectedDistrict(''); setSelectedWard('');
      LocationService.getDistricts(selectedProvince).then(setDistricts);
    }
  }, [selectedProvince]);

  useEffect(() => {
    if (selectedDistrict) {
      setWards([]); setSelectedWard('');
      LocationService.getWards(selectedDistrict).then(setWards);
    }
  }, [selectedDistrict]);

  useEffect(() => {
    const province = provinces.find(p => p.code === selectedProvince);
    const district = districts.find(d => d.code === selectedDistrict);
    const ward = wards.find(w => w.code === selectedWard);

    // Logic tạo địa chỉ hiển thị
    const parts = [street, ward?.full_name, district?.full_name, province?.full_name].filter(Boolean);
    
    // Gửi dữ liệu ra ngoài
    onLocationChange({
      province,
      district,
      ward,
      fullAddress: parts.join(', ')
    });
  }, [selectedProvince, selectedDistrict, selectedWard, street, provinces, districts, wards]);

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-3">
        <div>
          <select className="w-full border border-gray-300 rounded-md p-2 text-sm outline-none bg-white"
            value={selectedProvince} onChange={(e) => setSelectedProvince(e.target.value)}>
            <option value="">-- Tỉnh/Thành --</option>
            {provinces.map((p) => <option key={p.code} value={p.code}>{p.full_name || p.name}</option>)}
          </select>
        </div>
        <div>
          <select className="w-full border border-gray-300 rounded-md p-2 text-sm outline-none bg-white disabled:bg-gray-100"
            value={selectedDistrict} onChange={(e) => setSelectedDistrict(e.target.value)} disabled={!selectedProvince}>
            <option value="">-- Quận/Huyện --</option>
            {districts.map((d) => <option key={d.code} value={d.code}>{d.full_name || d.name}</option>)}
          </select>
        </div>
        <div>
          <select className="w-full border border-gray-300 rounded-md p-2 text-sm outline-none bg-white disabled:bg-gray-100"
            value={selectedWard} onChange={(e) => setSelectedWard(e.target.value)} disabled={!selectedDistrict}>
            <option value="">-- Phường/Xã --</option>
            {wards.map((w) => <option key={w.code} value={w.code}>{w.full_name || w.name}</option>)}
          </select>
        </div>
      </div>
      <div>
        <input type="text" className="w-full border border-gray-300 rounded-md p-2 text-sm outline-none focus:border-blue-500 transition"
          placeholder="Số nhà, tên đường..."
          value={street} onChange={(e) => setStreet(e.target.value)}
        />
      </div>
    </div>
  );
}
