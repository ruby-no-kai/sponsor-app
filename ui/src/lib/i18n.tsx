import type { Timestamp } from "@bufbuild/protobuf/wkt";
import { timestampDate } from "@bufbuild/protobuf/wkt";
import { Fragment, createContext, useContext, useMemo } from "react";
import type { ReactNode } from "react";
import { formatDateTime, lookup, splitTemplate, translate, translateHtml } from "./translations.ts";
import type { Translations, Vars } from "./translations.ts";

// The sponsor area's texts, as SponsorService.GetTranslations returns them. The staff area is
// English only and never provides it.
export type I18n = {
  locale: string;
  translations: Translations;
  orgName: string;
};

export type Translate = {
  // The text under key, or the key itself when the locale files lack it. `count` picks a plural
  // form, and `org_name` is filled in unless vars gives one.
  (key: string, vars?: Vars): string;
  // The text with elements in place of its variables, such as `{link: <a href="…">…</a>}`.
  rich(key: string, vars: Readonly<Record<string, ReactNode>>): ReactNode;
  // The text as HTML, for dangerouslySetInnerHTML. Only a key ending in "_html" keeps markup.
  html(key: string, vars?: Vars): string;
  // A timestamp in the browser's time zone, naming the zone.
  dateTime(timestamp: Timestamp): string;
  locale: string;
};

const I18nContext = createContext<I18n | undefined>(undefined);

export function I18nProvider({ value, children }: { value: I18n; children: ReactNode }) {
  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useT(): Translate {
  const i18n = useContext(I18nContext);
  if (i18n === undefined) throw new Error("useT needs an I18nProvider above it");
  return useMemo(() => translator(i18n), [i18n]);
}

function translator({ locale, translations, orgName }: I18n): Translate {
  const withOrgName = (vars: Vars = {}): Vars => ({ org_name: orgName, ...vars });

  const t = (key: string, vars?: Vars) => translate(translations, key, withOrgName(vars));
  t.rich = (key: string, vars: Readonly<Record<string, ReactNode>>): ReactNode => {
    const text = lookup(translations, key, withOrgName());
    if (text === undefined) return key;
    return splitTemplate(text).map((part, index) => {
      if ("text" in part) return <Fragment key={index}>{part.text}</Fragment>;
      const value =
        part.variable in vars
          ? vars[part.variable]
          : part.variable === "org_name"
            ? orgName
            : undefined;
      return <Fragment key={index}>{value ?? `%{${part.variable}}`}</Fragment>;
    });
  };
  t.html = (key: string, vars?: Vars) => translateHtml(translations, key, withOrgName(vars));
  t.dateTime = (timestamp: Timestamp) => formatDateTime(timestampDate(timestamp), locale);
  t.locale = locale;
  return t;
}
