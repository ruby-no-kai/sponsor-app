// TanStack Form's field metadata by field path, such as `fallbackOptions[1].value`, as far as the
// errors go.
export type FieldMetas = Readonly<Record<string, { errors: readonly unknown[] } | undefined>>;

// How an editor names and lays out the fields its paths lead to.
export type FieldLayout = {
  // Labels by the names in field paths, in the order the editor lays their fields out.
  labels: Readonly<Record<string, string>>;
  // Lists the editor lays out as cards of fields, by what it calls one element.
  elements?: Readonly<Record<string, string>>;
};

export type FieldError = { path: string; label: string; message: string };

type PathSegment = string | number;

// `fallbackOptions[1].value` as ["fallbackOptions", 1, "value"].
function pathSegments(path: string): PathSegment[] {
  return Array.from(path.matchAll(/([^.[\]]+)|\[(\d+)\]/g), ([, name, index]) =>
    index === undefined ? (name ?? "") : Number(index),
  );
}

// The path one step up, such as `fallbackOptions[1]` for `fallbackOptions[1].value`.
export function parentPath(path: string): string | undefined {
  const at = Math.max(path.lastIndexOf("."), path.lastIndexOf("["));
  return at <= 0 ? undefined : path.slice(0, at);
}

// The path of the field an error on `path` shows on. An element of a list of strings, such as
// `priorityHuman[1]`, has no field of its own and shows on its list.
export function errorAnchor(path: string, layout: FieldLayout): string {
  const segments = pathSegments(path);
  const [owner, last] = segments.slice(-2);
  const ownsFields = typeof owner === "string" && Object.hasOwn(layout.elements ?? {}, owner);
  return typeof last === "number" && !ownsFields ? (parentPath(path) ?? path) : path;
}

// What the editor calls the field at a path, such as "Option #2 › Value".
export function fieldLabel(path: string, layout: FieldLayout): string {
  const labels: string[] = [];
  let owner: PathSegment | undefined;
  for (const segment of pathSegments(path)) {
    if (typeof segment === "string") {
      labels.push(layout.labels[segment] ?? segment);
    } else {
      const element = typeof owner === "string" ? layout.elements?.[owner] : undefined;
      const last = labels.pop() ?? "";
      labels.push(element === undefined ? `${last} #${segment + 1}` : `${element} #${segment + 1}`);
    }
    owner = segment;
  }
  return labels.join(" › ");
}

// Orders paths as the editor lays out their fields, a list's own errors before its elements'.
function comparePaths(a: PathSegment[], b: PathSegment[], order: readonly string[]): number {
  const orderOf = (segment: PathSegment | undefined) => {
    if (typeof segment !== "string") return -1;
    const at = order.indexOf(segment);
    return at === -1 ? order.length : at;
  };
  for (let at = 0; at < Math.min(a.length, b.length); at++) {
    const [x, y] = [a[at], b[at]];
    if (x === y) continue;
    if (typeof x === "number" && typeof y === "number") return x - y;
    return orderOf(x) - orderOf(y);
  }
  return a.length - b.length;
}

const escapeRegExp = (text: string) => text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Error messages on a path, and with items on the elements of the list it names, such as
// `priorityHuman[1]`, which have no form field of their own.
export function errorsAt(
  fieldMeta: FieldMetas,
  path: string,
  { items = false }: { items?: boolean } = {},
): string[] {
  const itemPath = new RegExp(`^${escapeRegExp(path)}\\[(\\d+)\\]$`);
  return Object.entries(fieldMeta).flatMap(([name, meta]) => {
    const messages = (meta?.errors ?? []).filter(
      (error): error is string => typeof error === "string",
    );
    if (name === path) return messages;
    const item = items ? itemPath.exec(name) : null;
    return item === null ? [] : messages.map((message) => `#${Number(item[1]) + 1}: ${message}`);
  });
}

// The fields showing an error, in the order the editor lays them out, each with its first message.
export function erroredFields(fieldMeta: FieldMetas, layout: FieldLayout): FieldError[] {
  const order = Object.keys(layout.labels);
  const messages = Object.entries(fieldMeta)
    .flatMap(([name, meta]) => {
      const message = meta?.errors.find((error): error is string => typeof error === "string");
      return message === undefined ? [] : [{ name, segments: pathSegments(name), message }];
    })
    .sort((a, b) => comparePaths(a.segments, b.segments, order));

  const fields = new Map<string, FieldError>();
  for (const { name, segments, message } of messages) {
    const path = errorAnchor(name, layout);
    if (fields.has(path)) continue;
    const item = segments.at(-1);
    fields.set(path, {
      path,
      label: fieldLabel(path, layout),
      message: path === name || typeof item !== "number" ? message : `#${item + 1}: ${message}`,
    });
  }
  return [...fields.values()];
}
