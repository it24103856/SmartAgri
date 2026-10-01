import { useState } from 'react';
import api from '../services/api';

export default function UserAvatar({ user, className = 'h-16 w-16' }) {
  const [failedUrl, setFailedUrl] = useState(null);
  let imageUrl = null;
  try {
    if (user?.profileImageUrl) {
      const url = new URL(user.profileImageUrl, new URL(api.defaults.baseURL, window.location.origin));
      if (['http:', 'https:'].includes(url.protocol)) imageUrl = url.href;
    }
  } catch {
    // Invalid image URLs use the account initials.
  }
  const name = user?.fullName?.trim() || 'Admin';
  const initials = name.split(/\s+/).slice(0, 2).map(part => part[0]).join('').toUpperCase();
  return (
    <div className={`${className} shrink-0 rounded-full overflow-hidden bg-[#EAF4EE] text-[#1E3A2B] flex items-center justify-center font-bold text-xl`}>
      {imageUrl && failedUrl !== imageUrl ? (
        <img src={imageUrl} alt={`${name} profile`} className="h-full w-full object-cover" onError={() => setFailedUrl(imageUrl)} />
      ) : <span aria-label={`${name} profile`}>{initials}</span>}
    </div>
  );
}
