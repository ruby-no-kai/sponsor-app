import { createContext, useContext, useEffect } from "react";

// The name every title ends with. The sponsor area provides its own, in the viewer's language.
export const AppNameContext = createContext("Sponsor App");

// Titles the browser tab after the screen, most specific part first, then the app's name.
export function useDocumentTitle(...parts: (string | undefined)[]): void {
  const appName = useContext(AppNameContext);
  const title = [...parts.filter((part) => part !== undefined && part !== ""), appName].join(" · ");
  useEffect(() => {
    document.title = title;
  }, [title]);
}
