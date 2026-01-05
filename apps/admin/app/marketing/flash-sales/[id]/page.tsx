'use client';

import { useEffect, useState, use } from 'react';
import axios from 'axios';
import { ArrowLeft, Loader2 } from 'lucide-react';
import Link from 'next/link';
import PromotionForm from '@/components/marketing/PromotionForm';
import { useRouter } from 'next/navigation';

export default function EditFlashSalePage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const [promotion, setPromotion] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const baseURL = process.env.NEXT_PUBLIC_API_URL?.endsWith('/api/v1') 
            ? process.env.NEXT_PUBLIC_API_URL 
            : `${process.env.NEXT_PUBLIC_API_URL}/api/v1`;

        const res = await axios.get(`${baseURL}/marketing/promotions/${id}`);
        setPromotion(res.data.data);
      } catch (error) {
        console.error(error);
        alert('Không tìm thấy chương trình!');
        router.push('/marketing/flash-sales');
      } finally {
        setLoading(false);
      }
    };
    fetchData();
  }, [id, router]);

  if (loading) {
    return (
        <div className="h-screen flex flex-col items-center justify-center gap-2 text-orange-600">
            <Loader2 className="animate-spin" size={40} />
            <span className="font-medium">Đang tải dữ liệu...</span>
        </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Link href="/marketing/flash-sales" className="p-2 hover:bg-gray-100 rounded-full transition">
            <ArrowLeft className="w-5 h-5 text-gray-600" />
        </Link>
        <h1 className="text-2xl font-bold text-gray-800">Chỉnh sửa Flash Sale</h1>
      </div>
      
      {promotion && <PromotionForm initialData={promotion} promotionId={id} defaultType="flash_sale" />}
    </div>
  );
}
