"use client";
import { Settings } from "lucide-react";

export default function SettingsPage() {
  return (
    <div className="p-6 bg-gray-50 min-h-screen">
      <h1 className="text-2xl font-bold text-gray-800 flex items-center gap-2 mb-6">
        <Settings className="text-blue-600"/> Cấu hình hệ thống
      </h1>
      <div className="bg-white p-10 rounded-xl shadow border text-center text-gray-500">
        Tính năng đang được phát triển.
      </div>
    </div>
  );
}
