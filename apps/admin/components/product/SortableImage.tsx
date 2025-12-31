"use client";
import React from 'react';
import { useSortable } from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import { X, GripVertical } from 'lucide-react';

interface Props {
  id: string;
  url: string;
  index: number;
  onRemove: (index: number) => void;
}

export function SortableImage({ id, url, index, onRemove }: Props) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    zIndex: isDragging ? 50 : 0,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div ref={setNodeRef} style={style} className="relative w-28 h-28 border rounded-xl overflow-hidden group bg-gray-50 shadow-sm border-gray-200">
      <img src={url} className="w-full h-full object-cover" alt="product" />
      
      {/* Nút kéo */}
      <div {...attributes} {...listeners} className="absolute inset-0 bg-black/20 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center cursor-grab active:cursor-grabbing">
        <GripVertical className="text-white" size={24} />
      </div>

      {/* Badge ảnh bìa */}
      {index === 0 && (
        <div className="absolute top-0 left-0 bg-blue-600 text-white text-[9px] font-bold px-1.5 py-0.5 rounded-br-lg shadow-sm">
          ẢNH BÌA
        </div>
      )}

      {/* Nút xóa */}
      <button
        type="button"
        onClick={() => onRemove(index)}
        className="absolute top-1 right-1 bg-red-500 text-white p-1 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity z-10 shadow-md"
      >
        <X size={12} />
      </button>
    </div>
  );
}
