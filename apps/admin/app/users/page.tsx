"use client";
import React from 'react';
import { Construction } from 'lucide-react';

export default function Page() {
  return (
    <div className="flex flex-col items-center justify-center h-[60vh] text-gray-500">
      <div className="p-4 bg-gray-100 rounded-full mb-4">
        <Construction size={48} className="text-yellow-600" />
      </div>
      <h1 className="text-2xl font-bold text-gray-800">Quản Lý Khách Hàng</h1>
      <p className="mt-2 text-sm">Tính năng đang được phát triển.</p>
    </div>
  );
}
