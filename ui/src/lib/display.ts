// Values both areas show as the HAML pages do.

// Whether a sponsor-supplied URL is safe to link to: http or https, never javascript: and the like.
export function isWebUrl(url: string): boolean {
  try {
    return ["http:", "https:"].includes(new URL(url).protocol);
  } catch {
    return false;
  }
}

// A decimal string such as "120000.0" with thousands separators.
export function formatAmount(amount: string): string {
  const [integer = "", fraction] = amount.split(".");
  const grouped = integer.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return fraction === undefined || /^0*$/.test(fraction) ? grouped : `${grouped}.${fraction}`;
}
