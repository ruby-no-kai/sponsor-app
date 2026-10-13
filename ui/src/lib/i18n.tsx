import { createContext, useContext, useMemo } from "react";
import type { ReactNode } from "react";
import { translator } from "./translator.ts";
import type { I18n, Translate } from "./translator.ts";

export type { I18n, Translate };

const I18nContext = createContext<I18n | undefined>(undefined);

export function I18nProvider({ value, children }: { value: I18n; children: ReactNode }) {
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useT(): Translate {
  const i18n = useContext(I18nContext);
  if (i18n === undefined) throw new Error("useT needs an I18nProvider above it");
  return useMemo(() => translator(i18n), [i18n]);
}
