#!/bin/bash

FE_ROOT="/var/www/lica-project/apps/user"

echo "========================================================"
echo "   FIX FRONTEND CHECKOUT & LOCATION COMPONENT"
echo "========================================================"

# 1. Cập nhật Location Service
echo ">>> [1/3] Updating Location Service..."
cat << 'EOF' > $FE_ROOT/services/location.service.ts
import api from '@/lib/axios';

export interface LocationOption {
  code: string;
  name: string;
  full_name?: string;
  name_with_type?: string; // Tương thích ngược
}

export const LocationService = {
  getProvinces: async () => {
    try {
      const res = await api.get('/location/provinces');
      // Backend mới trả về { status: 200, data: [...] }
      return res.data.data || [];
    } catch (error) {
      console.error("Error fetching provinces:", error);
      return [];
    }
  },

  getDistricts: async (provinceCode: string) => {
    if (!provinceCode) return [];
    try {
      const res = await api.get(`/location/districts/${provinceCode}`);
      return res.data.data || [];
    } catch (error) {
      console.error("Error fetching districts:", error);
      return [];
    }
  },

  getWards: async (districtCode: string) => {
    if (!districtCode) return [];
    try {
      const res = await api.get(`/location/wards/${districtCode}`);
      return res.data.data || [];
    } catch (error) {
      console.error("Error fetching wards:", error);
      return [];
    }
  }
};
EOF

# 2. Cập nhật SmartLocationInput (Component chọn địa chỉ)
echo ">>> [2/3] Updating SmartLocationInput.tsx..."
cat << 'EOF' > $FE_ROOT/components/common/SmartLocationInput.tsx
'use client';

import { useState, useEffect } from 'react';
import { LocationService, LocationOption } from '@/services/location.service';

interface Props {
  onLocationChange: (data: {
    province?: LocationOption;
    district?: LocationOption;
    ward?: LocationOption;
    fullAddress: string;
  }) => void;
}

export default function SmartLocationInput({ onLocationChange }: Props) {
  const [provinces, setProvinces] = useState<LocationOption[]>([]);
  const [districts, setDistricts] = useState<LocationOption[]>([]);
  const [wards, setWards] = useState<LocationOption[]>([]);

  const [selectedProvince, setSelectedProvince] = useState<string>('');
  const [selectedDistrict, setSelectedDistrict] = useState<string>('');
  const [selectedWard, setSelectedWard] = useState<string>('');
  const [street, setStreet] = useState('');

  // Load Provinces on mount
  useEffect(() => {
    LocationService.getProvinces().then(setProvinces);
  }, []);

  // Load Districts when Province changes
  useEffect(() => {
    if (selectedProvince) {
      setDistricts([]);
      setWards([]);
      setSelectedDistrict('');
      setSelectedWard('');
      LocationService.getDistricts(selectedProvince).then(setDistricts);
    }
  }, [selectedProvince]);

  // Load Wards when District changes
  useEffect(() => {
    if (selectedDistrict) {
      setWards([]);
      setSelectedWard('');
      LocationService.getWards(selectedDistrict).then(setWards);
    }
  }, [selectedDistrict]);

  // Notify parent whenever selection changes
  useEffect(() => {
    const province = provinces.find(p => p.code === selectedProvince);
    const district = districts.find(d => d.code === selectedDistrict);
    const ward = wards.find(w => w.code === selectedWard);

    const parts = [street, ward?.full_name, district?.full_name, province?.full_name].filter(Boolean);
    
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
        {/* Tỉnh/Thành */}
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Tỉnh / Thành phố</label>
          <select 
            className="w-full border border-gray-300 rounded-md p-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none bg-white"
            value={selectedProvince}
            onChange={(e) => setSelectedProvince(e.target.value)}
          >
            <option value="">-- Chọn Tỉnh/Thành --</option>
            {provinces.map((p) => (
              <option key={p.code} value={p.code}>{p.full_name || p.name}</option>
            ))}
          </select>
        </div>

        {/* Quận/Huyện */}
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Quận / Huyện</label>
          <select 
            className="w-full border border-gray-300 rounded-md p-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none bg-white disabled:bg-gray-100"
            value={selectedDistrict}
            onChange={(e) => setSelectedDistrict(e.target.value)}
            disabled={!selectedProvince}
          >
            <option value="">-- Chọn Quận/Huyện --</option>
            {districts.map((d) => (
              <option key={d.code} value={d.code}>{d.full_name || d.name}</option>
            ))}
          </select>
        </div>

        {/* Phường/Xã */}
        <div>
          <label className="block text-xs font-medium text-gray-700 mb-1">Phường / Xã</label>
          <select 
            className="w-full border border-gray-300 rounded-md p-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none bg-white disabled:bg-gray-100"
            value={selectedWard}
            onChange={(e) => setSelectedWard(e.target.value)}
            disabled={!selectedDistrict}
          >
            <option value="">-- Chọn Phường/Xã --</option>
            {wards.map((w) => (
              <option key={w.code} value={w.code}>{w.full_name || w.name}</option>
            ))}
          </select>
        </div>
      </div>

      {/* Số nhà/Tên đường */}
      <div>
        <label className="block text-xs font-medium text-gray-700 mb-1">Địa chỉ cụ thể (Số nhà, đường)</label>
        <input 
          type="text" 
          className="w-full border border-gray-300 rounded-md p-2 text-sm focus:ring-2 focus:ring-blue-500 outline-none"
          placeholder="Ví dụ: 123 Nguyễn Văn Linh..."
          value={street}
          onChange={(e) => setStreet(e.target.value)}
        />
      </div>
    </div>
  );
}
EOF

# 3. Build lại Frontend
echo ">>> [3/3] Rebuilding Frontend..."
cd $FE_ROOT
npm run build

echo "========================================================"
echo "   ĐÃ CẬP NHẬT FRONTEND. HÃY RESTART VÀ KIỂM TRA."
echo "========================================================"
