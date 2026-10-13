// Wraps each occurrence of a token in the text of an HTML string in <mark>, leaving tags and
// their attributes as they are.
export function markPlaceholders(html: string, tokens: readonly string[]): string {
  if (tokens.length === 0) return html;
  const pattern = new RegExp(tokens.map(escapeRegExp).join("|"), "g");
  return html
    .split(/(<[^>]*>)/)
    .map((part) => (part.startsWith("<") ? part : part.replace(pattern, "<mark>$&</mark>")))
    .join("");
}

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}
