export function formatAmount(amount: string, decimal?: number): string {
  const num = parseFloat(amount);
  if (isNaN(num)) return amount;
  return decimal !== undefined
    ? num.toLocaleString(undefined, {
        minimumFractionDigits: decimal,
        maximumFractionDigits: decimal,
      })
    : num.toLocaleString();
}
