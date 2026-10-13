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
  size,
  title,
  description,
  confirmLabel,
  onConfirm,
}: {
  label: string;
  icon?: Icon;
  iconOnly?: boolean;
  variant?: "primary" | "destructive";
  size?: "sm" | "base";
  title: string;
  description: ReactNode;
  confirmLabel: string;
  onConfirm: () => Promise<void>;
}) {
  const [open, setOpen] = useState(false);
  const [isRunning, setIsRunning] = useState(false);

  async function handleConfirm() {
    setIsRunning(true);
    try {
      await onConfirm();
      setOpen(false);
    } catch (error) {
      notifyError(error);
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
            <Button {...props} variant={variant} icon={icon} size={size}>
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
                Cancel
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
