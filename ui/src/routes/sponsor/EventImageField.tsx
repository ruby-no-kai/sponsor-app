import { Button, Link, Meter, Text } from "@cloudflare/kumo";
import { useState } from "react";
import { ErrorList } from "../../lib/FormParts.tsx";
import { FilePicker } from "../../lib/FilePicker.tsx";
import { useT } from "../../lib/i18n.tsx";
import type { Progress } from "../../lib/upload.ts";
import type { EventImage } from "./sponsorEventForm.ts";

// The image types the event image takes.
const ACCEPT = "image/png,image/jpeg,image/webp";

// The image the event has: the Rails page redirecting to the file in the storage.
export type CurrentImage = { href: string; extension: string };

type Field = {
  name: string;
  state: { value: EventImage; meta: { errors: readonly unknown[] } };
  handleChange: (value: EventImage) => void;
};

// The event image picker, which can replace or remove the image the event has. A chosen file goes
// up to the storage when the form is sent.
export function EventImageField({
  field,
  initial,
  current,
  progress,
}: {
  field: Field;
  // The value the form started from, which Cancel goes back to.
  initial: EventImage;
  current: CurrentImage | undefined;
  progress: Progress | undefined;
}) {
  const t = useT();
  const [replacing, setReplacing] = useState(false);
  const value = field.state.value;
  const uploading = progress !== undefined;
  const showPicker = value.kind !== "existing" || replacing;
  const canCancel = value.kind === "file" || replacing || initial.kind !== value.kind;

  const reset = () => {
    setReplacing(false);
    field.handleChange(initial);
  };

  return (
    <div className="flex flex-col gap-2" data-field={field.name}>
      {current !== undefined && (
        <div>
          <Link href={current.href} target="_blank" rel="noreferrer">
            {t("sponsor_ui.events.image.download", { extension: current.extension })}
          </Link>
        </div>
      )}
      {value.kind === "none" && initial.kind === "existing" && (
        <Text variant="secondary" size="sm">
          {t("sponsor_ui.events.image.removing")}
        </Text>
      )}
      <div className="flex flex-wrap items-center gap-2">
        {showPicker ? (
          <FilePicker
            file={value.kind === "file" ? value.file : undefined}
            accept={ACCEPT}
            label={t("sponsor_events.form.asset_file")}
            chooseLabel={t("sponsor_ui.files.choose")}
            removeLabel={t("sponsor_ui.files.remove")}
            disabled={uploading}
            onChoose={(file) =>
              field.handleChange(file === undefined ? initial : { kind: "file", file })
            }
          />
        ) : (
          <>
            <Button variant="secondary" size="sm" onClick={() => setReplacing(true)}>
              {t("sponsor_ui.events.image.replace")}
            </Button>
            <Button
              variant="secondary-destructive"
              size="sm"
              onClick={() => field.handleChange({ kind: "none" })}
            >
              {t("sponsor_ui.events.image.remove")}
            </Button>
          </>
        )}
        {showPicker && canCancel && !uploading && (
          <Button variant="ghost" size="sm" onClick={reset}>
            {t("sponsor_ui.events.image.cancel")}
          </Button>
        )}
      </div>
      {uploading && (
        <Meter
          label={t("sponsor_ui.events.image.uploading")}
          value={progress.total === 0 ? 0 : Math.round((progress.loaded / progress.total) * 100)}
        />
      )}
      <ErrorList errors={field.state.meta.errors} />
    </div>
  );
}
