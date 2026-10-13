import { Button, Dialog } from "@cloudflare/kumo";
import type { Icon } from "@phosphor-icons/react";
import { useState } from "react";
import type { ReactNode } from "react";
import { notifyError } from "../../lib/toast.ts";

// A button that asks first, destructive unless told otherwise. A failed action shows a toast and
// leaves the dialog open. With iconOnly, the label is the button's accessible name.
export function ConfirmButton({
  label,
  icon,
  iconOnly = false,
  variant = "destructive",
  triggerVariant = variant,
  size,
  title,
  description,
  confirmLabel,
  cancelLabel = "Cancel",
  onConfirm,
  onError = notifyError,
}: {
  label: string;
  icon?: Icon;
  iconOnly?: boolean;
  variant?: "primary" | "destructive";
  // How the button that opens the dialog looks, such as a quieter "secondary-destructive".
  triggerVariant?: "primary" | "destructive" | "secondary-destructive";
  size?: "sm" | "base";
  title: string;
  description: ReactNode;
  confirmLabel: string;
  cancelLabel?: string;
  onConfirm: () => Promise<void>;
  // Reports a failed action. The default words it in English, as the staff area does.
  onError?: (error: unknown) => void;
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
    <Dialog.Root open={open} onOpenChange={setOpen}>
      <Dialog.Trigger
        render={(props) =>
          iconOnly ? (
            <Button
              {...props}
              variant="ghost"
              shape="square"
              icon={icon}
              size={size}
              aria-label={label}
            />
          ) : (
            <Button {...props} variant={triggerVariant} icon={icon} size={size}>
              {label}
            </Button>
          )
        }
      />
      <Dialog className="flex flex-col gap-4 p-6" size="sm">
        <Dialog.Title className="text-lg font-semibold">{title}</Dialog.Title>
        <Dialog.Description className="text-kumo-subtle">{description}</Dialog.Description>
        <div className="flex justify-end gap-2">
          <Dialog.Close
            render={(props) => (
              <Button {...props} variant="secondary">
                {cancelLabel}
              </Button>
            )}
          />
          <Button variant={variant} loading={isRunning} onClick={() => void handleConfirm()}>
            {confirmLabel}
          </Button>
        </div>
      </Dialog>
    </Dialog.Root>
  );
}
