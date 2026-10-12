import { useEffect } from "react";

const APP_NAME = "Sponsor App";

// Titles the browser tab after the screen, most specific part first, then the app's name.
export function useDocumentTitle(...parts: (string | undefined)[]): void {
  const title = [...parts.filter((part) => part !== undefined && part !== ""), APP_NAME].join(
    " · ",
  );
  useEffect(() => {
    document.title = title;
  }, [title]);
}
