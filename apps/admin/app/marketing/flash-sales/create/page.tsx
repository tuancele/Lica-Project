'use client';

import PromotionForm from '@/components/marketing/PromotionForm';
import { ArrowLeft } from 'lucide-react';
import Link from 'next/link';

export default function CreateFlashSalePage() {
  return (
    <div className="space-y-6">
      <div className="flex items-center gap-4">
        <Link href="/marketing/flash-sales" className="p-2 hover:bg-gray-100 rounded-full">
            <ArrowLeft className="w-5 h-5 text-gray-600" />
        </Link>
        <h1 className="text-2xl font-bold text-gray-800">Tạo Flash Sale Mới</h1>
      </div>
      
      {/* Mặc định type là flash_sale */}
      <PromotionForm defaultType="flash_sale" />
    </div>
  );
}
