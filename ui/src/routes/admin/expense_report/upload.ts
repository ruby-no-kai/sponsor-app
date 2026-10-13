// What ExpenseFileUploadInput.content_type takes.
export const ALLOWED_CONTENT_TYPES: readonly string[] = [
  "image/jpeg",
  "image/png",
  "image/gif",
  "image/webp",
  "application/pdf",
];

export function isAllowedFile(file: Pick<File, "type">): boolean {
  return ALLOWED_CONTENT_TYPES.includes(file.type);
}
