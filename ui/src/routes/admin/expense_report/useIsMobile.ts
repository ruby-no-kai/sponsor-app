import { useEffect, useState } from "react";

// Tailwind's md breakpoint, below which the editor shows one pane at a time.
const QUERY = "(max-width: 767px)";

export function useIsMobile(): boolean {
  const [isMobile, setIsMobile] = useState(() => window.matchMedia(QUERY).matches);

  useEffect(() => {
    const query = window.matchMedia(QUERY);
    const handleChange = (event: MediaQueryListEvent) => setIsMobile(event.matches);
    query.addEventListener("change", handleChange);
    return () => query.removeEventListener("change", handleChange);
  }, []);

  return isMobile;
}
