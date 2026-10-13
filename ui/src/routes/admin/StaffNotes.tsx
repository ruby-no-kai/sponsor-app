import { Badge, Banner, Button, Checkbox, InputArea, Text } from "@cloudflare/kumo";
import { ConnectError } from "@connectrpc/connect";
import {
  PencilSimpleIcon,
  PushPinIcon,
  PushPinSlashIcon,
  TrashIcon,
  WarningIcon,
} from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { useSWRConfig } from "swr";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import type { SponsorshipStaffNote } from "../../gen/rubykaigi/sponsor_app/sponsorship_staff_note_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import { formatTimestamp } from "../../lib/forms.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { isRpcKeyOf, useRpcMutation } from "../../lib/rpc.ts";
import { notifyError } from "../../lib/toast.ts";
import { RpcErrorDetails } from "../RouteError.tsx";
import { ConfirmButton } from "./ConfirmButton.tsx";
import { joined } from "./FormParts.tsx";
import { SandboxedHtml } from "./SandboxedHtml.tsx";

// Named after SponsorshipStaffNoteInput's JSON fields, as the violations of a rejected save are.
type NoteValues = { body: string; pinned: boolean };

const EMPTY_NOTE: NoteValues = { body: "", pinned: false };

type NoteTarget = { conferenceSlug: string; sponsorshipId: bigint };

// Both the sponsorship page and the notes page show notes, so a change revalidates both.
function useRevalidateNotes(): () => Promise<unknown> {
  const { mutate } = useSWRConfig();
  return () =>
    mutate(
      (key) =>
        isRpcKeyOf(key, AdminService.method.getSponsorship) ||
        isRpcKeyOf(key, AdminService.method.listSponsorshipStaffNotes),
    );
}

// A form adding a note, then the notes, each with its own edit, pin and delete.
export function StaffNotes({
  target,
  notes,
}: {
  target: NoteTarget;
  notes: readonly SponsorshipStaffNote[];
}) {
  const createNote = useRpcMutation(AdminService.method.createSponsorshipStaffNote);
  const revalidate = useRevalidateNotes();

  return (
    <div className="flex flex-col gap-3">
      <NoteForm
        initial={EMPTY_NOTE}
        submitLabel="Add note"
        save={async (input) => {
          await createNote.trigger({ ...target, input });
        }}
        onSaved={revalidate}
      />
      {notes.length === 0 && <Text variant="secondary">No notes yet.</Text>}
      <ul className="flex flex-col divide-y divide-kumo-hairline">
        {notes.map((note) => (
          <li key={note.id.toString()} className="py-3">
            <NoteItem target={target} note={note} />
          </li>
        ))}
      </ul>
    </div>
  );
}

function NoteItem({ target, note }: { target: NoteTarget; note: SponsorshipStaffNote }) {
  const [isEditing, setIsEditing] = useState(false);
  const updateNote = useRpcMutation(AdminService.method.updateSponsorshipStaffNote);
  const deleteNote = useRpcMutation(AdminService.method.deleteSponsorshipStaffNote);
  const revalidate = useRevalidateNotes();
  const noteTarget = { ...target, staffNoteId: note.id };

  async function togglePin() {
    try {
      await updateNote.trigger({ ...noteTarget, input: { body: note.body, pinned: !note.pinned } });
    } catch (error) {
      notifyError(error);
      return;
    }
    await revalidate();
  }

  if (isEditing) {
    return (
      <NoteForm
        initial={{ body: note.body, pinned: note.pinned }}
        submitLabel="Save"
        save={async (input) => {
          await updateNote.trigger({ ...noteTarget, input });
        }}
        onSaved={async () => {
          setIsEditing(false);
          await revalidate();
        }}
        onCancel={() => setIsEditing(false)}
      />
    );
  }

  return (
    <div className="flex flex-col gap-2">
      <SandboxedHtml html={note.bodyHtml} title={`Note by ${note.staffLogin}`} />
      <div className="flex flex-wrap items-center justify-between gap-2">
        <Text variant="secondary" size="sm">
          {note.staffLogin}, {formatTimestamp(note.updatedAt)}{" "}
          {note.pinned && <Badge variant="info">Pinned</Badge>}
        </Text>
        <span className="flex gap-1">
          <Button
            variant="ghost"
            shape="square"
            size="sm"
            icon={PencilSimpleIcon}
            aria-label="Edit note"
            onClick={() => setIsEditing(true)}
          />
          <Button
            variant="ghost"
            shape="square"
            size="sm"
            icon={note.pinned ? PushPinSlashIcon : PushPinIcon}
            aria-label={note.pinned ? "Unpin note" : "Pin note"}
            loading={updateNote.isMutating}
            onClick={() => void togglePin()}
          />
          <ConfirmButton
            label="Delete note"
            icon={TrashIcon}
            iconOnly
            size="sm"
            title="Delete this note?"
            description="The note is removed for every organizer. This cannot be undone."
            confirmLabel="Delete"
            onConfirm={async () => {
              await deleteNote.trigger(noteTarget);
              await revalidate();
            }}
          />
        </span>
      </div>
    </div>
  );
}

function NoteForm({
  initial,
  submitLabel,
  save,
  onSaved,
  onCancel,
}: {
  initial: NoteValues;
  submitLabel: string;
  save: (input: NoteValues) => Promise<void>;
  onSaved: () => Promise<unknown>;
  onCancel?: () => void;
}) {
  // The error of the last save, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const rejection = useSaveRejection();
  const form = useForm({
    defaultValues: initial,
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      try {
        await save(value);
      } catch (error) {
        setSaveError(error);
        rejection.reject(formApi, value, fieldViolations(error, { prefix: "input." }));
        return;
      }
      setSaveError(undefined);
      formApi.reset();
      await onSaved();
    },
  });

  return (
    <form
      className="flex flex-col gap-2"
      noValidate
      onSubmit={(event) => {
        event.preventDefault();
        void rejection.submit(form);
      }}
    >
      <form.Field name="body">
        {(field) => (
          <InputArea
            label="Note"
            description="Markdown supported"
            autoResize
            minRows={2}
            maxRows={12}
            value={field.state.value}
            onValueChange={field.handleChange}
            onBlur={field.handleBlur}
            error={joined(field.state.meta.errors)}
          />
        )}
      </form.Field>
      <form.Subscribe selector={(state) => [state.errorMap.onChange, state.isSubmitting] as const}>
        {([formError, isSubmitting]) => (
          <>
            {typeof formError === "string" && (
              <Banner
                variant="error"
                icon={<WarningIcon />}
                title="Not saved"
                description={
                  <div className="flex flex-col gap-2">
                    <div>{formError}</div>
                    {saveError !== undefined && (
                      <RpcErrorDetails error={ConnectError.from(saveError)} withCode />
                    )}
                  </div>
                }
              />
            )}
            <div className="flex items-center justify-between gap-2">
              <form.Field name="pinned">
                {(field) => (
                  <Checkbox
                    label="Pin"
                    checked={field.state.value}
                    onCheckedChange={(checked) => field.handleChange(checked === true)}
                  />
                )}
              </form.Field>
              <span className="flex gap-2">
                {onCancel !== undefined && (
                  <Button variant="secondary" size="sm" onClick={onCancel}>
                    Cancel
                  </Button>
                )}
                <Button type="submit" variant="primary" size="sm" loading={isSubmitting}>
                  {submitLabel}
                </Button>
              </span>
            </div>
          </>
        )}
      </form.Subscribe>
    </form>
  );
}
