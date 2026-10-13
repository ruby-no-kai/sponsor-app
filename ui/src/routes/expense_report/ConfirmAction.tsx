import { Button, Dialog } from "@cloudflare/kumo";
import type { Icon } from "@phosphor-icons/react";
import { useState } from "react";
import type { ReactNode } from "react";

type Variant = "primary" | "secondary" | "secondary-destructive" | "destructive";

// A button that asks first. `beforeOpen` may refuse to ask, such as when the form it acts on is
// not valid. A failed action goes to `onError` and leaves the dialog open.
export function ConfirmAction({
  label,
  icon,
  variant = "secondary-destructive",
  confirmVariant = "destructive",
  size,
  title,
  description,
  confirmLabel,
  cancelLabel,
  beforeOpen,
  onConfirm,
  onError,
}: {
  label: string;
  icon?: Icon;
  variant?: Variant;
  confirmVariant?: "primary" | "destructive";
  size?: "sm" | "base";
  title: string;
  description: ReactNode;
  confirmLabel: string;
  cancelLabel: string;
  beforeOpen?: () => boolean;
  onConfirm: () => Promise<void>;
  onError: (error: unknown) => void;
}) {
  const [open, setOpen] = useState(false);
  const [isRunning, setIsRunning] = useState(false);

  async function handleConfirm() {
    setIsRunning(true);
    try {
      await onConfirm();
      setOpen(false);
    } catch (error) {
      onError(error);
    } finally {
      setIsRunning(false);
    }
  }

  return (
    <>
      <Button
        variant={variant}
        icon={icon}
        size={size}
        onClick={() => {
          if (beforeOpen === undefined || beforeOpen()) setOpen(true);
        }}
      >
        {label}
      </Button>
      <Dialog.Root open={open} onOpenChange={(next) => !isRunning && setOpen(next)}>
        <Dialog className="flex flex-col gap-4 px-6 py-5" size="sm">
          <Dialog.Title className="text-lg font-semibold">{title}</Dialog.Title>
          <Dialog.Description className="text-kumo-subtle">{description}</Dialog.Description>
          <div className="flex justify-end gap-2">
            <Button variant="secondary" disabled={isRunning} onClick={() => setOpen(false)}>
              {cancelLabel}
            </Button>
            <Button
              variant={confirmVariant}
              loading={isRunning}
              onClick={() => void handleConfirm()}
            >
              {confirmLabel}
            </Button>
          </div>
        </Dialog>
      </Dialog.Root>
    </>
  );
}
