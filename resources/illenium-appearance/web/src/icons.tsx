// Lightweight inline-SVG icon set (feather-style) — replaces `react-icons`
// to keep the production build small. API: <Icon size={16} />.
import { ReactNode } from 'react';

interface IProps {
  size?: number;
}

const S = ({ size = 16, children }: IProps & { children: ReactNode }) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth={2}
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    {children}
  </svg>
);

export const FiChevronDown = (p: IProps) => (
  <S {...p}>
    <polyline points="6 9 12 15 18 9" />
  </S>
);
export const FiChevronUp = (p: IProps) => (
  <S {...p}>
    <polyline points="18 15 12 9 6 15" />
  </S>
);
export const FaVideo = (p: IProps) => (
  <S {...p}>
    <polygon points="23 7 16 12 23 17 23 7" />
    <rect x="1" y="5" width="15" height="14" rx="2" ry="2" />
  </S>
);
export const FaStreetView = (p: IProps) => (
  <S {...p}>
    <polyline points="23 4 23 10 17 10" />
    <polyline points="1 20 1 14 7 14" />
    <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
  </S>
);
export const FaRedo = (p: IProps) => (
  <S {...p}>
    <polyline points="23 4 23 10 17 10" />
    <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10" />
  </S>
);
export const FaUndo = (p: IProps) => (
  <S {...p}>
    <polyline points="1 4 1 10 7 10" />
    <path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10" />
  </S>
);
export const FaSmile = (p: IProps) => (
  <S {...p}>
    <circle cx="12" cy="12" r="10" />
    <path d="M8 14s1.5 2 4 2 4-2 4-2" />
    <line x1="9" y1="9" x2="9.01" y2="9" />
    <line x1="15" y1="9" x2="15.01" y2="9" />
  </S>
);
export const FaMale = (p: IProps) => (
  <S {...p}>
    <circle cx="12" cy="4" r="2" />
    <path d="M12 6v9M12 15l-3 5M12 15l3 5M8 9h8" />
  </S>
);
export const FaShoePrints = (p: IProps) => (
  <S {...p}>
    <path d="M4 16h13a3 3 0 0 0 3-3V9l-6-4H8a4 4 0 0 0-4 4v7z" />
    <path d="M4 16v2a2 2 0 0 0 2 2h9" />
  </S>
);
export const FaSave = (p: IProps) => (
  <S {...p}>
    <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z" />
    <polyline points="17 21 17 13 7 13 7 21" />
    <polyline points="7 3 7 8 15 8" />
  </S>
);
export const FaTimes = (p: IProps) => (
  <S {...p}>
    <line x1="18" y1="6" x2="6" y2="18" />
    <line x1="6" y1="6" x2="18" y2="18" />
  </S>
);
export const FaTshirt = (p: IProps) => (
  <S {...p}>
    <path d="M4 7l4-3 2 2h4l2-2 4 3-3 3v10H7V10L4 7z" />
  </S>
);
export const FaHatCowboy = (p: IProps) => (
  <S {...p}>
    <path d="M2 17c3 1.5 5 2 10 2s7-.5 10-2" />
    <path d="M6 17c0-5 1.5-11 6-11s6 6 6 11" />
  </S>
);
export const FaSocks = (p: IProps) => (
  <S {...p}>
    <path d="M9 3v7l-3.5 4a3 3 0 0 0 4.2 4.2L16 15V3" />
    <path d="M9 3h7" />
  </S>
);
export const FaWalking = (p: IProps) => (
  <S {...p}>
    <circle cx="13" cy="4" r="2" />
    <path d="M13 6l-1 5 3 3 1 6M12 11l-4 2M15 14l3 1" />
  </S>
);
export const FaRunning = (p: IProps) => (
  <S {...p}>
    <circle cx="14" cy="4" r="2" />
    <path d="M14 6l-4 4 3 3 1 6M10 10l-4 3M15 13l4 1" />
  </S>
);
export const FaHandPaper = (p: IProps) => (
  <S {...p}>
    <path d="M6 12V6a1.5 1.5 0 0 1 3 0v4M9 10V4a1.5 1.5 0 0 1 3 0v6M12 10V5a1.5 1.5 0 0 1 3 0v6M15 12V8a1.5 1.5 0 0 1 3 0v6a6 6 0 0 1-6 6h-1a6 6 0 0 1-5-2.7L4 14a1.5 1.5 0 0 1 2.5-1.6L8 14" />
  </S>
);
export const FaRegStopCircle = (p: IProps) => (
  <S {...p}>
    <circle cx="12" cy="12" r="10" />
    <rect x="9" y="9" width="6" height="6" rx="1" />
  </S>
);
