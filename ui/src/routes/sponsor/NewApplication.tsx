import { Banner, LayerCard, Loader, Select, Text } from "@cloudflare/kumo";
import { timestampDate } from "@bufbuild/protobuf/wkt";
import { InfoIcon, WarningIcon } from "@phosphor-icons/react";
import { useEffect } from "react";
import { useParams, useSearchParams } from "react-router";
import type { Conference } from "../../gen/rubykaigi/sponsor_app/conference_pb.ts";
import type { SponsorServiceGetApplicationFormResponse } from "../../gen/rubykaigi/sponsor_app/sponsor_applications_pb.ts";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { idToInput } from "../../lib/forms.ts";
import { useT } from "../../lib/i18n.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { ApplicationEditor } from "./ApplicationEditor.tsx";
import type { CurrentAssetFile } from "./AssetFileField.tsx";
import { assetFileHref } from "./applicationForm.ts";
import { dashboardPath } from "./shellRedirects.ts";

// The query parameters the links to the form carry, from invitation and affiliation emails and
// from the form's own choice of an application to copy.
const INVITE_CODE = "invite_code";
const AFFILIATION = "affiliation";
const COPY = "sponsorship_id_to_copy";

export default function NewApplication() {
  const { slug = "" } = useParams();
  const [searchParams, setSearchParams] = useSearchParams();
  const t = useT();
  const goTo = useGoTo();
  const inviteCode = searchParams.get(INVITE_CODE) ?? "";
  const affiliation = searchParams.get(AFFILIATION) ?? "";
  const copyParam = searchParams.get(COPY) ?? "";
  const copyId = /^\d+$/.test(copyParam) ? BigInt(copyParam) : undefined;
  const { data, error } = useRpc(SponsorService.method.getApplicationForm, {
    conferenceSlug: slug,
    inviteCode,
    affiliation,
    sponsorshipIdToCopy: copyId,
  });
  const closed = data !== undefined && !data.applicationOpen && !data.staffOverride;
  useDocumentTitle(
    t(closed ? "sponsorships.closed.title" : "sponsorships.new.title"),
    data?.form?.conference?.name,
  );

  // A contact who has applied manages the application from the dashboard.
  const alreadyApplied = data?.alreadyApplied ?? false;
  useEffect(() => {
    if (alreadyApplied) goTo(dashboardPath(slug), { replace: true });
  }, [alreadyApplied, slug, goTo]);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined || alreadyApplied) return <Loader size="lg" />;
  const { form } = data;
  if (form?.conference === undefined) throw new Error("GetApplicationForm returned no form");
  // A closed conference's form has only the conference.
  if (closed) return <ApplicationClosed conference={form.conference} />;
  if (form.description === undefined) {
    throw new Error("GetApplicationForm returned no form description");
  }

  const chooseCopy = (id: string) =>
    setSearchParams(
      (current) => {
        const next = new URLSearchParams(current);
        if (id === "") next.delete(COPY);
        else next.set(COPY, id);
        return next;
      },
      { replace: true },
    );

  return (
    <div className="flex flex-col gap-4">
      {data.staffOverride && <StaffPreviewNotice conference={form.conference} />}
      {data.affiliatedOrganizationName !== undefined && (
        <Banner
          variant="default"
          icon={<InfoIcon />}
          title={t("sponsorships.form.affiliated_organization_notice", {
            organization: data.affiliatedOrganizationName,
          })}
        />
      )}
      <ApplicationEditor
        key={copyParam}
        slug={slug}
        conference={form.conference}
        plans={form.plans}
        description={form.description}
        application={data.copiedApplication}
        currentAsset={copiedAsset(data, copyId)}
        mode={{ kind: "new", inviteCode, affiliation }}
        intro={<CopyChooser data={data} copyParam={copyParam} onChoose={chooseCopy} />}
      />
    </div>
  );
}

// The logo of the application copied from, which the new one copies unless another is chosen.
function copiedAsset(
  data: SponsorServiceGetApplicationFormResponse,
  copyId: bigint | undefined,
): CurrentAssetFile | undefined {
  const assetFile = data.copiedApplication?.assetFile;
  const source = data.copySources.find(({ id }) => id === copyId)?.conference;
  if (assetFile === undefined || source === undefined) return undefined;
  return {
    href: assetFileHref(source.slug, assetFile.id),
    extension: assetFile.extension,
    copiedFrom: source.name,
  };
}

// Fills the form in from another of the contact's applications. A copy asked for by a visitor
// who is not signed in needs signing in first.
function CopyChooser({
  data,
  copyParam,
  onChoose,
}: {
  data: SponsorServiceGetApplicationFormResponse;
  copyParam: string;
  onChoose: (id: string) => void;
}) {
  const t = useT();
  const sources = data.copySources;
  if (sources.length === 0) {
    return copyParam === "" ? null : (
      <Banner
        variant="default"
        icon={<InfoIcon />}
        title={t("sponsorships.form.copy.login_required")}
      />
    );
  }

  const chosen = sources.some(({ id }) => idToInput(id) === copyParam) ? copyParam : null;
  return (
    <LayerCard>
      <LayerCard.Secondary>{t("sponsorships.form.copy.header")}</LayerCard.Secondary>
      <LayerCard.Primary className="flex flex-col gap-3">
        <Text>{t("sponsorships.form.copy.explanation")}</Text>
        <Select
          aria-label={t("sponsorships.form.copy.header")}
          className="min-w-60"
          placeholder={t("sponsorships.form.fallback_option_blank")}
          value={chosen}
          onValueChange={(value) => onChoose(String(value ?? ""))}
          items={sources.map(({ id, conference, name }) => ({
            label: conference?.name ?? name,
            value: idToInput(id),
          }))}
        />
      </LayerCard.Primary>
    </LayerCard>
  );
}

// What staff see while the conference takes no applications, which they may submit anyway.
function StaffPreviewNotice({ conference }: { conference: Conference }) {
  const t = useT();
  const opensAt = conference.applicationOpensAt;
  return (
    <Banner
      variant="alert"
      icon={<WarningIcon />}
      title={t("sponsor_ui.applications.staff_preview")}
      description={
        opensAt === undefined
          ? undefined
          : t("sponsor_ui.applications.opens_at", { ts: t.dateTime(opensAt) })
      }
    />
  );
}

function ApplicationClosed({ conference }: { conference: Conference }) {
  const t = useT();
  const { applicationOpensAt: opensAt, applicationClosesAt: closesAt } = conference;
  const ended = closesAt !== undefined && timestampDate(closesAt) <= new Date();
  return (
    <div className="flex flex-col gap-3">
      <Text variant="heading" size="lg" as="h1">
        {t("sponsorships.closed.header")}
      </Text>
      <Text>
        {ended
          ? t("sponsorships.closed.closed", { ts: t.dateTime(closesAt) })
          : t("sponsorships.closed.not_yet_open", {
              ts: opensAt === undefined ? "" : t.dateTime(opensAt),
            })}
      </Text>
    </div>
  );
}
