import axios from 'axios';

const api = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
});

export const getImageUrl = (path: string | string[] | any) => {
  // 1. Nếu không có path -> Trả về placeholder
  if (!path) return 'https://placehold.co/300x300?text=No+Image';

  let finalPath = path;

  // 2. Nếu là Array -> Lấy phần tử đầu tiên
  if (Array.isArray(path)) {
    if (path.length === 0) return 'https://placehold.co/300x300?text=No+Image';
    finalPath = path[0];
  } 
  // 3. Nếu là String nhưng dạng JSON mảng '["img.jpg"]' -> Parse lấy phần tử đầu
  else if (typeof path === 'string' && path.startsWith('[')) {
    try {
        const parsed = JSON.parse(path);
        if (Array.isArray(parsed) && parsed.length > 0) finalPath = parsed[0];
    } catch (e) {
        // Parse lỗi thì giữ nguyên string gốc
    }
  }

  // 4. Đảm bảo finalPath là string
  if (typeof finalPath !== 'string') return 'https://placehold.co/300x300?text=Error';

  // 5. Kiểm tra http
  if (finalPath.startsWith('http')) return finalPath;
  
  // 6. Ghép với Storage URL
  // Xóa dấu / ở đầu nếu có để tránh //
  const cleanPath = finalPath.startsWith('/') ? finalPath.substring(1) : finalPath;
  return `${process.env.NEXT_PUBLIC_STORAGE_URL}/${cleanPath}`;
};

export default api;
