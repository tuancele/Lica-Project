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
