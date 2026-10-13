import { Button, Dialog, Meter, Text } from "@cloudflare/kumo";
import {
  CheckCircleIcon,
  CircleNotchIcon,
  HourglassIcon,
  MinusCircleIcon,
  XCircleIcon,
} from "@phosphor-icons/react";
import type { Icon } from "@phosphor-icons/react";
import { useEditor } from "./EditorContext.ts";
import type { UploadEntry, UploadState } from "./useFileUpload.ts";

const STATUS_ICONS: Readonly<Record<UploadEntry["status"], { icon: Icon; className: string }>> = {
  waiting: { icon: HourglassIcon, className: "text-kumo-subtle" },
  uploading: { icon: CircleNotchIcon, className: "animate-spin text-kumo-info" },
  done: { icon: CheckCircleIcon, className: "text-kumo-success" },
  failed: { icon: XCircleIcon, className: "text-kumo-danger" },
  discarded: { icon: MinusCircleIcon, className: "text-kumo-subtle" },
};

// Stays open until every file is stored or discarded, as leaving mid-way would lose the queue.
export function UploadDialog({
  state,
  onRetry,
  onDiscard,
}: {
  state: UploadState;
  onRetry: () => void;
  onDiscard: () => void;
}) {
  const { text } = useEditor();
  const active = state.kind === "active" ? state : undefined;
  const percent =
    active === undefined || active.total === 0
      ? 0
      : Math.round((active.loaded / active.total) * 100);

  return (
    <Dialog.Root open={active !== undefined} onOpenChange={() => undefined}>
      <Dialog className="flex flex-col gap-4 px-6 py-5" size="sm">
        <Dialog.Title className="text-lg font-semibold">
          {active?.failed ? text("upload_failed") : text("uploading")}
        </Dialog.Title>
        <Meter label={text("upload_progress")} value={percent} showValue />
        <ul className="flex max-h-52 flex-col gap-1 overflow-auto">
          {active?.entries.map((entry, index) => {
            const { icon: StatusIcon, className } = STATUS_ICONS[entry.status];
            return (
              <li key={index} className="flex items-start gap-2">
                <StatusIcon
                  size={18}
                  className={`mt-0.5 shrink-0 ${className}`}
                  aria-label={text(`upload_status_${entry.status}`)}
                />
                <Text size="sm">
                  {entry.name}
                  {entry.error !== undefined && (
                    <span className="text-kumo-danger"> ({entry.error})</span>
                  )}
                </Text>
              </li>
            );
          })}
        </ul>
        {active?.failed && (
          <div className="flex justify-end gap-2">
            <Button variant="secondary" onClick={onDiscard}>
              {text("discard")}
            </Button>
            <Button variant="primary" onClick={onRetry}>
              {text("retry")}
            </Button>
          </div>
        )}
      </Dialog>
    </Dialog.Root>
  );
}
