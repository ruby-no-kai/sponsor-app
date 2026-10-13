import { Checkbox, InputArea, Loader, Select, Text } from "@cloudflare/kumo";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { messagesAt } from "../../lib/fieldErrors.ts";
import { idToInput } from "../../lib/forms.ts";
import { useRpc } from "../../lib/rpc.ts";
import { ErrorList, joined } from "./FormParts.tsx";
import {
  ANY,
  KIND_ITEMS,
  LOCALE_ITEMS,
  RECIPIENT_FILTER_LABELS as LABELS,
  STATUS_ITEMS,
  emailsFromInput,
  isRecipientFilterKind,
  isSponsorshipStatusName,
  sortedByName,
  sponsorshipDetailText,
} from "./recipientFilterForm.ts";
import type { RecipientFilterValues, SponsorshipStatusName } from "./recipientFilterForm.ts";

// A recipient filter's kind and the fields of that kind. `path` is where `value` sits in the form,
// and `errors` holds the form's errors below it by the rest of their path, as errorsUnder in
// lib/fieldErrors.ts returns.
export function RecipientFilterFields({
  slug,
  path,
  value,
  onChange,
  errors,
  allowNone,
}: {
  slug: string;
  path: string;
  value: RecipientFilterValues;
  onChange: (value: RecipientFilterValues) => void;
  errors: Readonly<Record<string, readonly string[]>>;
  allowNone: boolean;
}) {
  const set = <K extends keyof RecipientFilterValues>(key: K, next: RecipientFilterValues[K]) =>
    onChange({ ...value, [key]: next });
  const fieldPath = (rest: string) => `${path}.${rest}`;
  const errorOf = (rest: string, elements?: readonly string[]) =>
    joined(messagesAt(errors, rest, elements));

  return (
    <div className="flex flex-col gap-4" data-field={path}>
      <div data-field={fieldPath("kind")}>
        <Select
          label={LABELS.kind}
          className="min-w-80"
          value={value.kind}
          onValueChange={(kind) => {
            if (isRecipientFilterKind(kind)) set("kind", kind);
          }}
          items={allowNone ? KIND_ITEMS : KIND_ITEMS.filter((item) => item.value !== "none")}
          error={joined([...(errors[""] ?? []), ...(errors["kind"] ?? [])])}
        />
      </div>

      {value.kind === "currentSponsors" && (
        <CurrentSponsorsFields
          slug={slug}
          value={value.currentSponsors}
          onChange={(next) => set("currentSponsors", next)}
          fieldPath={(rest) => fieldPath(`currentSponsors.${rest}`)}
          errorOf={(rest) => errorOf(`currentSponsors.${rest}`)}
        />
      )}
      {value.kind === "pastSponsors" && (
        <PastSponsorsFields
          slug={slug}
          value={value.pastSponsors}
          onChange={(next) => set("pastSponsors", next)}
          fieldPath={(rest) => fieldPath(`pastSponsors.${rest}`)}
          errorOf={(rest) => errorOf(`pastSponsors.${rest}`)}
        />
      )}
      {value.kind === "manual" && (
        <ManualFields
          slug={slug}
          sponsorshipIds={value.manual.sponsorshipIds}
          onChange={(sponsorshipIds) => set("manual", { sponsorshipIds })}
          dataField={fieldPath("manual.sponsorshipIds")}
          errorOf={(names) => errorOf("manual.sponsorshipIds", names)}
        />
      )}
      {value.kind === "raw" && (
        <div data-field={fieldPath("raw.emails")}>
          <InputArea
            label={LABELS.emails}
            description="One per line. @LOGIN@ links these to the sign-in page, as they have no sponsorship."
            autoResize
            minRows={4}
            maxRows={16}
            className="font-mono"
            value={value.raw.emails}
            onValueChange={(emails) => set("raw", { emails })}
            error={errorOf("raw.emails", emailsFromInput(value.raw.emails))}
          />
        </div>
      )}
      <ErrorList errors={errors[value.kind] ?? []} />
    </div>
  );
}

type SubsetProps<T> = {
  slug: string;
  value: T;
  onChange: (value: T) => void;
  fieldPath: (rest: string) => string;
  errorOf: (rest: string) => string | undefined;
};

function CurrentSponsorsFields({
  slug,
  value,
  onChange,
  fieldPath,
  errorOf,
}: SubsetProps<RecipientFilterValues["currentSponsors"]>) {
  const plans = useRpc(AdminService.method.getConference, { conferenceSlug: slug }).data?.plans;

  return (
    <>
      <div className="grid gap-4 md:grid-cols-2">
        <LocaleField
          dataField={fieldPath("locale")}
          value={value.locale}
          onChange={(locale) => onChange({ ...value, locale })}
          error={errorOf("locale")}
        />
        <div data-field={fieldPath("planId")}>
          <Select
            label={LABELS.planId}
            value={value.planId === "" ? ANY : value.planId}
            onValueChange={(planId) =>
              onChange({ ...value, planId: planId === ANY ? "" : String(planId ?? "") })
            }
            items={[
              { label: "Any", value: ANY },
              ...(plans ?? []).map((plan) => ({ label: plan.name, value: idToInput(plan.id) })),
            ]}
            error={errorOf("planId")}
          />
        </div>
      </div>
      <div className="flex flex-col gap-1" data-field={fieldPath("exhibitorsOnly")}>
        <Checkbox
          label={LABELS.exhibitorsOnly}
          checked={value.exhibitorsOnly}
          onCheckedChange={(checked) => onChange({ ...value, exhibitorsOnly: checked === true })}
        />
        <ErrorList errors={[errorOf("exhibitorsOnly")]} />
      </div>
      <StatusField
        dataField={fieldPath("status")}
        value={value.status}
        onChange={(status) => onChange({ ...value, status })}
        error={errorOf("status")}
      />
    </>
  );
}

function PastSponsorsFields({
  value,
  onChange,
  fieldPath,
  errorOf,
}: SubsetProps<RecipientFilterValues["pastSponsors"]>) {
  const { data } = useRpc(AdminService.method.listConferences, {});

  return (
    <>
      <div className="grid gap-4 md:grid-cols-2">
        <div data-field={fieldPath("conferenceSlug")}>
          <Select
            label={LABELS.conferenceSlug}
            placeholder="Choose a conference"
            value={value.conferenceSlug}
            onValueChange={(slug) => onChange({ ...value, conferenceSlug: String(slug ?? "") })}
            items={(data?.conferences ?? []).flatMap(({ conference }) =>
              conference === undefined ? [] : [{ label: conference.name, value: conference.slug }],
            )}
            description="Only the conferences you may manage are listed."
            error={errorOf("conferenceSlug")}
          />
        </div>
        <LocaleField
          dataField={fieldPath("locale")}
          value={value.locale}
          onChange={(locale) => onChange({ ...value, locale })}
          error={errorOf("locale")}
        />
      </div>
      <StatusField
        dataField={fieldPath("status")}
        value={value.status}
        onChange={(status) => onChange({ ...value, status })}
        error={errorOf("status")}
      />
    </>
  );
}

function ManualFields({
  slug,
  sponsorshipIds,
  onChange,
  dataField,
  errorOf,
}: {
  slug: string;
  sponsorshipIds: readonly string[];
  onChange: (sponsorshipIds: string[]) => void;
  dataField: string;
  errorOf: (names: readonly string[]) => string | undefined;
}) {
  const { data } = useRpc(AdminService.method.getConference, { conferenceSlug: slug });
  if (data === undefined) return <Loader />;

  const sponsorships = sortedByName(data.sponsorships);
  const planNameOf = new Map(data.plans.map((plan) => [plan.id, plan.name]));
  const nameOf = new Map(
    sponsorships.map((sponsorship) => [idToInput(sponsorship.id), sponsorship.name]),
  );
  if (sponsorships.length === 0) {
    return <Text variant="secondary">This conference has no sponsorship to pick.</Text>;
  }

  return (
    <div data-field={dataField}>
      <Checkbox.Group
        legend={LABELS.sponsorshipIds}
        value={[...sponsorshipIds]}
        onValueChange={onChange}
        error={errorOf(sponsorshipIds.map((id) => nameOf.get(id) ?? id))}
      >
        {sponsorships.map((sponsorship) => (
          <Checkbox.Item
            key={sponsorship.id.toString()}
            value={idToInput(sponsorship.id)}
            label={`${sponsorship.name} (${sponsorshipDetailText(
              sponsorship.state,
              sponsorship.planId === undefined ? undefined : planNameOf.get(sponsorship.planId),
            )})`}
          />
        ))}
      </Checkbox.Group>
    </div>
  );
}

function LocaleField({
  dataField,
  value,
  onChange,
  error,
}: {
  dataField: string;
  value: string;
  onChange: (value: string) => void;
  error: string | undefined;
}) {
  return (
    <div data-field={dataField}>
      <Select
        label={LABELS.locale}
        value={value === "" ? ANY : value}
        onValueChange={(locale) => onChange(locale === ANY ? "" : String(locale ?? ""))}
        items={LOCALE_ITEMS}
        description="The language the sponsor reads email in."
        error={error}
      />
    </div>
  );
}

function StatusField({
  dataField,
  value,
  onChange,
  error,
}: {
  dataField: string;
  value: SponsorshipStatusName;
  onChange: (value: SponsorshipStatusName) => void;
  error: string | undefined;
}) {
  return (
    <div data-field={dataField}>
      <Select
        label={LABELS.status}
        className="min-w-60"
        value={value}
        onValueChange={(status) => {
          if (isSponsorshipStatusName(status)) onChange(status);
        }}
        items={STATUS_ITEMS}
        error={error}
      />
    </div>
  );
}
