"use client";
import { useState, useEffect, useRef } from "react";
import axios from "axios";
import { MapPin, Search, X, Loader2 } from "lucide-react";

interface LocationResult {
  label: string;
  province_code: string;
  district_code: string;
  ward_code: string;
  province_name: string;
  district_name: string;
  ward_name: string;
}

interface Props {
  onSelect: (data: LocationResult) => void;
  initialLabel?: string;
}

export default function SmartLocationInput({ onSelect, initialLabel = "" }: Props) {
  const [query, setQuery] = useState(initialLabel);
  const [results, setResults] = useState<LocationResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [isOpen, setIsOpen] = useState(false);
  const wrapperRef = useRef<HTMLDivElement>(null);

  // Debounce search
  useEffect(() => {
    const timer = setTimeout(async () => {
      if (query.length < 2 || query === initialLabel) return;
      
      setLoading(true);
      try {
        const res = await axios.get(`${process.env.NEXT_PUBLIC_API_URL}/api/v1/location/search?q=${query}`);
        setResults(res.data.data);
        setIsOpen(true);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }, 400); // Wait 400ms after typing

    return () => clearTimeout(timer);
  }, [query, initialLabel]);

  // Sync initial label
  useEffect(() => {
    if (initialLabel) setQuery(initialLabel);
  }, [initialLabel]);

  // Click outside to close
  useEffect(() => {
    function handleClickOutside(event: any) {
      if (wrapperRef.current && !wrapperRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [wrapperRef]);

  const handleSelect = (item: LocationResult) => {
    setQuery(item.label);
    setIsOpen(false);
    onSelect(item);
  };

  const handleClear = () => {
    setQuery("");
    setResults([]);
    onSelect({
      label: "", province_code: "", district_code: "", ward_code: "",
      province_name: "", district_name: "", ward_name: ""
    });
  };

  return (
    <div className="relative" ref={wrapperRef}>
      <div className="relative">
        <MapPin className="absolute left-3 top-3 text-gray-400" size={18} />
        <input
          type="text"
          className="w-full border border-gray-300 rounded-lg pl-10 pr-10 py-2.5 outline-none focus:ring-2 focus:ring-blue-500 transition shadow-sm"
          placeholder="Nhập Phường/Xã để tìm nhanh (VD: Đại Mỗ)"
          value={query}
          onChange={(e) => {
             setQuery(e.target.value);
             if(!e.target.value) setIsOpen(false);
          }}
          onFocus={() => { if(results.length > 0) setIsOpen(true); }}
        />
        {loading ? (
            <Loader2 className="absolute right-3 top-3 animate-spin text-blue-500" size={18} />
        ) : query && (
            <button onClick={handleClear} className="absolute right-3 top-3 text-gray-400 hover:text-red-500">
                <X size={18}/>
            </button>
        )}
      </div>

      {isOpen && results.length > 0 && (
        <div className="absolute z-50 w-full bg-white border border-gray-200 rounded-lg shadow-xl mt-1 max-h-60 overflow-y-auto">
          <ul>
            {results.map((item, idx) => (
              <li
                key={idx}
                onClick={() => handleSelect(item)}
                className="px-4 py-3 hover:bg-blue-50 cursor-pointer border-b last:border-0 text-sm text-gray-700 flex flex-col"
              >
                <span className="font-medium text-gray-900">{item.ward_name}</span>
                <span className="text-xs text-gray-500">{item.district_name}, {item.province_name}</span>
              </li>
            ))}
          </ul>
        </div>
      )}
      
      {isOpen && results.length === 0 && !loading && query.length >= 2 && (
         <div className="absolute z-50 w-full bg-white border border-gray-200 rounded-lg shadow-xl mt-1 p-3 text-center text-sm text-gray-500">
            Không tìm thấy địa chỉ nào.
         </div>
      )}
    </div>
  );
}
