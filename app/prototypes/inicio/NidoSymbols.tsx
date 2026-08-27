type SymbolProps = { className?: string };

const common = {
  width: 24,
  height: 24,
  viewBox: "0 0 24 24",
  fill: "none",
  xmlns: "http://www.w3.org/2000/svg",
  "aria-hidden": true,
} as const;

export function NidoMark({ className }: SymbolProps) {
  return <svg {...common} className={className}>
    <path d="M4.25 13.25c1.7 3.25 4.28 5 7.75 5s6.05-1.75 7.75-5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    <path d="M6.55 10.7c1.35 1.82 3.16 2.73 5.45 2.73 2.3 0 4.11-.91 5.45-2.73" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    <path d="M15.78 3.9a4.35 4.35 0 1 0 3.85 6.37 4.82 4.82 0 0 1-3.85-6.37Z" fill="currentColor" />
  </svg>;
}

export function SleepSymbol({ className }: SymbolProps) {
  return <svg {...common} className={className}>
    <path d="M14.82 2.72A8.5 8.5 0 1 0 21.3 15.34a9.4 9.4 0 0 1-6.48-12.62Z" fill="currentColor" />
    <path d="m18.65 4.72.48 1.12 1.12.48-1.12.48-.48 1.12-.48-1.12-1.12-.48 1.12-.48.48-1.12Z" fill="currentColor" opacity=".48" />
  </svg>;
}

export function FeedSymbol({ className }: SymbolProps) {
  return <svg {...common} className={className}>
    <path fill="currentColor" fillRule="evenodd" d="M9.15 2.5a1 1 0 0 0-.98 1.2l.53 2.6-2.05 2.82a4.7 4.7 0 0 0-.9 2.76v6.42a3.2 3.2 0 0 0 3.2 3.2h6.1a3.2 3.2 0 0 0 3.2-3.2v-6.42c0-1-.32-1.97-.9-2.76L15.3 6.3l.53-2.6a1 1 0 0 0-.98-1.2h-5.7Zm.55 2h4.6l-.24 1.2H9.94L9.7 4.5Zm-.25 6.15a.75.75 0 0 1 .75-.75h3.6a.75.75 0 0 1 0 1.5h-3.6a.75.75 0 0 1-.75-.75Z" />
    <path d="M7.75 14.15h8.5v4.05a1.3 1.3 0 0 1-1.3 1.3h-5.9a1.3 1.3 0 0 1-1.3-1.3v-4.05Z" fill="currentColor" opacity=".34" />
  </svg>;
}

export function DiaperSymbol({ className }: SymbolProps) {
  return <svg {...common} className={className}>
    <path d="M3.25 5.4h17.5v7.25a8.75 8.75 0 0 1-17.5 0V5.4Z" fill="currentColor" />
    <path d="M3.25 8.45h4.2l2.02 2.02a3.58 3.58 0 0 0 5.06 0l2.02-2.02h4.2v4.2c0 1.45-.36 2.82-1 4.02a8.92 8.92 0 0 0-3.54-2.9 9.04 9.04 0 0 0-8.42 0 8.92 8.92 0 0 0-3.54 2.9 8.66 8.66 0 0 1-1-4.02v-4.2Z" fill="currentColor" opacity=".38" />
    <circle cx="6.6" cy="7" r=".85" fill="white" fillOpacity=".72" /><circle cx="17.4" cy="7" r=".85" fill="white" fillOpacity=".72" />
  </svg>;
}

export function CareSymbol({ className }: SymbolProps) {
  return <svg {...common} className={className}>
    <path fill="currentColor" fillRule="evenodd" d="M12 21.15S3.35 16.25 3.35 9.4A5.05 5.05 0 0 1 12 5.85 5.05 5.05 0 0 1 20.65 9.4c0 6.85-8.65 11.75-8.65 11.75Zm-1.05-12.2v2.1h-2.1v1.9h2.1v2.1h2.1v-2.1h2.1v-1.9h-2.1v-2.1h-2.1Z" />
  </svg>;
}

export function NoteSymbol({ className }: SymbolProps) {
  return <svg {...common} className={className}>
    <path fill="currentColor" fillRule="evenodd" d="M5 2.75h9.25L19 7.5v13.75H5V2.75Zm9.25 1.9V7.5h2.85l-2.85-2.85ZM8.2 11a.8.8 0 0 0 0 1.6h7.6a.8.8 0 0 0 0-1.6H8.2Zm0 3.7a.8.8 0 0 0 0 1.6h5.2a.8.8 0 0 0 0-1.6H8.2Z" />
  </svg>;
}

export function MomentSymbol({ className }: SymbolProps) {
  return <svg {...common} className={className}>
    <path d="M11.9 3.7c.38 2.82 1.6 4.04 4.42 4.42-2.82.38-4.04 1.6-4.42 4.42-.38-2.82-1.6-4.04-4.42-4.42 2.82-.38 4.04-1.6 4.42-4.42Z" fill="currentColor" />
    <path d="M17.95 12.55c.2 1.53.87 2.2 2.4 2.4-1.53.2-2.2.87-2.4 2.4-.2-1.53-.87-2.2-2.4-2.4 1.53-.2 2.2-.87 2.4-2.4ZM6.25 13.4c.24 1.8 1.02 2.58 2.82 2.82-1.8.24-2.58 1.02-2.82 2.82-.24-1.8-1.02-2.58-2.82-2.82 1.8-.24 2.58-1.02 2.82-2.82Z" fill="currentColor" opacity=".7" />
  </svg>;
}
