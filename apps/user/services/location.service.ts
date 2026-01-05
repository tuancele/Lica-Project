import api from '@/lib/axios';

export interface LocationItem {
  code: string | number;
  name: string;
  name_with_type?: string;
}

export const LocationService = {
  getProvinces: async () => {
    try {
      const res = await api.get('/location/provinces');
      return res.data.data || [];
    } catch (error) {
      return [];
    }
  },
  getDistricts: async (provinceCode: string | number) => {
    if (!provinceCode) return [];
    try {
      const res = await api.get(`/location/districts/${provinceCode}`);
      return res.data.data || [];
    } catch (error) {
      return [];
    }
  },
  getWards: async (districtCode: string | number) => {
    if (!districtCode) return [];
    try {
      const res = await api.get(`/location/wards/${districtCode}`);
      return res.data.data || [];
    } catch (error) {
      return [];
    }
  }
};
