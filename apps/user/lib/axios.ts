import axios from 'axios';

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
});

export const getImageUrl = (path: string | null | undefined) => {
  if (!path) return 'https://placehold.co/300x300?text=No+Image';
  if (path.startsWith('http')) return path;
  return `${process.env.NEXT_PUBLIC_STORAGE_URL}/${path}`;
};

export default api;
