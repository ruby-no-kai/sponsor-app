import { LayerCard } from "@cloudflare/kumo";
import { useEffect, useRef, useState } from "react";
import type { ReactNode, RefObject } from "react";
import { parentPath } from "./fieldErrors.ts";

function messagesOf(errors: readonly unknown[]): string[] {
  return errors.filter((error): error is string => typeof error === "string");
}

// For an input's `error` prop, which takes one message.
export function joined(errors: readonly unknown[]): string | undefined {
  const messages = messagesOf(errors);
  return messages.length === 0 ? undefined : messages.join("; ");
}

// What a field render prop receives, as far as these inputs read it.
export type FieldOf<T> = {
  name: string;
  state: { value: T; meta: { errors: readonly unknown[] } };
  handleChange: (value: T) => void;
  handleBlur: () => void;
};

export function Section({
  title,
  id,
  children,
}: {
  title: string;
  // Makes the section a target of an anchor link.
  id?: string;
  children: ReactNode;
}) {
  return (
    <LayerCard id={id} className="scroll-mt-4">
      <LayerCard.Secondary>{title}</LayerCard.Secondary>
      <LayerCard.Primary className="flex flex-col gap-4">{children}</LayerCard.Primary>
    </LayerCard>
  );
}

// The save area of a long form in the sponsor area, pinned to the bottom of the viewport across
// the page's padding: the save buttons and, above them, the error summary of a rejected save.
export function StickySaveBar({ banner, children }: { banner?: ReactNode; children: ReactNode }) {
  return (
    <div className="sticky bottom-0 z-10 -mx-4 flex max-h-[50svh] flex-col gap-2 overflow-y-auto border-t border-kumo-line bg-kumo-base px-4 py-3 md:-mx-6 md:px-6">
      {banner}
      <div className="flex flex-wrap items-center gap-3">{children}</div>
    </div>
  );
}

// A field's errors as a list, for a field whose input shows none. `field` marks it for
// useFieldReveal.
export function ErrorList({ field, errors }: { field?: string; errors: readonly unknown[] }) {
  const messages = messagesOf(errors);
  if (messages.length === 0) return null;
  return (
    <ul className="list-inside list-disc text-kumo-danger" data-field={field}>
      {messages.map((message) => (
        <li key={message}>{message}</li>
      ))}
    </ul>
  );
}

// Scrolls the form to the field a path names, found by its data-field attribute, once the form
// has rendered the errors that may add it.
export function useFieldReveal(): {
  formRef: RefObject<HTMLFormElement | null>;
  reveal: (path: string) => void;
} {
  const formRef = useRef<HTMLFormElement>(null);
  // A fresh object per call, so the same field is scrolled to again.
  const [target, setTarget] = useState<{ path: string }>();

  useEffect(() => {
    if (target !== undefined) revealField(formRef.current, target.path);
  }, [target]);

  return { formRef, reveal: (path) => setTarget({ path }) };
}

// Scrolls to the field at a path, or else the nearest one enclosing it, and focuses a text field.
function revealField(form: HTMLFormElement | null, path: string): void {
  for (let at: string | undefined = path; at !== undefined; at = parentPath(at)) {
    const element = form?.querySelector<HTMLElement>(`[data-field="${CSS.escape(at)}"]`);
    if (element === null || element === undefined) continue;
    element.scrollIntoView({ behavior: "smooth", block: "center" });
    if (element.matches("input, textarea")) element.focus({ preventScroll: true });
    return;
  }
}
