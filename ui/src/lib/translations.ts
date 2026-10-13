// Rails I18n texts as SponsorService.GetTranslations serves them: flattened to dotted keys, with
// `%{name}` variables and plural forms under ".zero", ".one" and ".other".

export type Translations = Readonly<Record<string, string>>;

export type Vars = Readonly<Record<string, string | number>>;

// A template cut at its variables, in order.
export type TemplatePart = { text: string } | { variable: string };

const VARIABLE = /%\{(\w+)\}/g;

// I18n's default rule: the zero form for 0 when the text has one, one for 1, else other.
export function pluralKey(translations: Translations, key: string, count: number): string {
  if (count === 0 && `${key}.zero` in translations) return `${key}.zero`;
  return count === 1 ? `${key}.one` : `${key}.other`;
}

// The text under key, or its plural form when vars carries a numeric count and the key is
// pluralized. Undefined when neither exists.
export function lookup(
  translations: Translations,
  key: string,
  vars: Vars = {},
): string | undefined {
  const text = translations[key];
  if (text !== undefined) return text;

  const { count } = vars;
  return typeof count === "number" ? translations[pluralKey(translations, key, count)] : undefined;
}

// Replaces each `%{name}` with its value. A variable without a value stays as written, so the gap
// shows rather than vanishing.
export function interpolate(template: string, vars: Vars): string {
  return template.replace(VARIABLE, (placeholder, name: string) => {
    const value = vars[name];
    return value === undefined ? placeholder : String(value);
  });
}

// The text under key with its variables filled in, or the key itself when the locale files lack
// it, so a missing text is visible.
export function translate(translations: Translations, key: string, vars: Vars = {}): string {
  const text = lookup(translations, key, vars);
  return text === undefined ? key : interpolate(text, vars);
}

export function splitTemplate(template: string): TemplatePart[] {
  const parts: TemplatePart[] = [];
  let last = 0;
  for (const match of template.matchAll(VARIABLE)) {
    if (match.index > last) parts.push({ text: template.slice(last, match.index) });
    parts.push({ variable: match[1] ?? "" });
    last = match.index + match[0].length;
  }
  if (last < template.length) parts.push({ text: template.slice(last) });
  return parts;
}

export function escapeHtml(text: string): string {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

// The text under key as HTML. Only a key ending in "_html" may carry markup, as in Rails views;
// any other text, and every variable, is escaped.
export function translateHtml(translations: Translations, key: string, vars: Vars = {}): string {
  const text = lookup(translations, key, vars);
  if (text === undefined) return escapeHtml(key);

  const escaped = Object.fromEntries(
    Object.entries(vars).map(([name, value]) => [name, escapeHtml(String(value))]),
  );
  return key.endsWith("_html") ? interpolate(text, escaped) : escapeHtml(interpolate(text, vars));
}

// A date and time in the browser's time zone, naming the zone, as the server keeps UTC.
export function formatDateTime(date: Date, locale: string, timeZone?: string): string {
  return new Intl.DateTimeFormat(locale, {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZoneName: "short",
    timeZone,
  }).format(date);
}
