import { createContext, useContext } from "react";
import type { EditorI18n } from "./types";

const I18nContext = createContext<EditorI18n>({} as EditorI18n);

export const I18nProvider = I18nContext.Provider;

export function useI18n(): EditorI18n {
  return useContext(I18nContext);
}

export function t(template: string, vars: Record<string, string>): string {
  return template.replace(/%\{(\w+)\}/g, (_, key) => vars[key] ?? "");
}

export function splitAt(template: string, placeholder: string): [string, string] {
  const token = `%{${placeholder}}`;
  const idx = template.indexOf(token);
  if (idx < 0) return [template, ""];
  return [template.slice(0, idx), template.slice(idx + token.length)];
}
