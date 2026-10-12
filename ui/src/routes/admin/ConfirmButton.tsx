import { Button, Dialog } from "@cloudflare/kumo";
import type { Icon } from "@phosphor-icons/react";
import { useState } from "react";
import type { ReactNode } from "react";
import { notifyError } from "../../lib/toast.ts";

// A destructive button that asks first. A failed action shows a toast and leaves the dialog open.
export function ConfirmButton({
  label,
  icon,
  title,
  description,
  confirmLabel,
  onConfirm,
}: {
  label: string;
  icon?: Icon;
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
        render={(props) => (
          <Button {...props} variant="destructive" icon={icon}>
            {label}
          </Button>
        )}
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
          <Button variant="destructive" loading={isRunning} onClick={() => void handleConfirm()}>
            {confirmLabel}
          </Button>
        </div>
      </Dialog>
    </Dialog.Root>
  );
}
