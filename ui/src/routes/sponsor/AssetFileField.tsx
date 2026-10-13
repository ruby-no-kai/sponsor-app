import { Button, Link, Meter, Text } from "@cloudflare/kumo";
import { useState } from "react";
import { ErrorList } from "../../lib/FormParts.tsx";
import { FilePicker } from "../../lib/FilePicker.tsx";
import { useT } from "../../lib/i18n.tsx";
import type { Progress } from "../../lib/upload.ts";
import type { AssetChoice } from "./applicationForm.ts";

// What the HAML form's file picker accepts. The server takes a few more types than these.
const ACCEPT = "image/svg,image/svg+xml,application/pdf,application/zip,.ai,.eps";

// A logo the application has, or copies from another of the contact's applications.
export type CurrentAssetFile = {
  // The Rails page redirecting to the file in the storage.
  href: string;
  extension: string;
  // Name of the conference whose application the logo is copied from.
  copiedFrom?: string;
};

type Field = {
  name: string;
  state: { value: AssetChoice; meta: { errors: readonly unknown[] } };
  handleChange: (value: AssetChoice) => void;
};

// The logo picker. A chosen file goes up to the storage when the form is sent.
export function AssetFileField({
  field,
  initial,
  current,
  progress,
}: {
  field: Field;
  // The value the form started from, which Cancel goes back to.
  initial: AssetChoice;
  current: CurrentAssetFile | undefined;
  progress: Progress | undefined;
}) {
  const t = useT();
  const [replacing, setReplacing] = useState(false);
  const value = field.state.value;
  const picking = value.kind !== "existing" || replacing;

  return (
    <div className="flex flex-col gap-2" data-field={field.name}>
      {current !== undefined && (
        <div className="flex flex-col gap-1">
          {current.copiedFrom !== undefined && (
            <Text>
              {t("sponsor_ui.applications.asset_file.copied", { conference: current.copiedFrom })}
            </Text>
          )}
          <Link href={current.href} target="_blank" rel="noreferrer">
            {t("sponsor_ui.applications.asset_file.download", { extension: current.extension })}
          </Link>
        </div>
      )}
      {picking ? (
        <div className="flex flex-col items-start gap-2">
          <FilePicker
            file={value.kind === "file" ? value.file : undefined}
            accept={ACCEPT}
            label={t("sponsorships.form.logo")}
            chooseLabel={t("sponsor_ui.files.choose")}
            removeLabel={t("sponsor_ui.files.remove")}
            disabled={progress !== undefined}
            onChoose={(file) =>
              field.handleChange(file === undefined ? initial : { kind: "file", file })
            }
          />
          {initial.kind === "existing" && progress === undefined && (
            <Button
              variant="secondary"
              size="sm"
              onClick={() => {
                setReplacing(false);
                field.handleChange(initial);
              }}
            >
              {t("sponsor_ui.applications.asset_file.cancel")}
            </Button>
          )}
        </div>
      ) : (
        <div>
          <Button variant="secondary" size="sm" onClick={() => setReplacing(true)}>
            {t("sponsor_ui.applications.asset_file.replace")}
          </Button>
        </div>
      )}
      {progress !== undefined && (
        <Meter
          label={t("sponsor_ui.applications.asset_file.uploading")}
          value={progress.total === 0 ? 0 : Math.round((progress.loaded / progress.total) * 100)}
        />
      )}
      <ErrorList errors={field.state.meta.errors} />
    </div>
  );
}
