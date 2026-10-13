import { Banner, Link, Loader, Text } from "@cloudflare/kumo";
import { WarningIcon } from "@phosphor-icons/react";
import { useParams } from "react-router";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { ApplicationEditor } from "./ApplicationEditor.tsx";
import { assetFileHref } from "./applicationForm.ts";
import { dashboardPath } from "./shellRedirects.ts";

// A browser without a sponsor session is sent to sign in, which brings it back here.
export default function EditApplication() {
  const { slug = "" } = useParams();
  const t = useT();
  const { data, error } = useRpc(SponsorService.method.getSponsorshipApplication, {
    conferenceSlug: slug,
  });
  useDocumentTitle(t("sponsorships.edit.title"), data?.form?.conference?.name);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const { form, application } = data;
  if (
    form?.conference === undefined ||
    form.description === undefined ||
    application === undefined
  ) {
    throw new Error("GetSponsorshipApplication returned no application");
  }
  const { conference } = form;
  const assetFile = application.assetFile;

  return (
    <div className="flex flex-col gap-4">
      <div>
        <Link href={dashboardPath(slug)}>{t("sponsor_ui.applications.back_to_portal")}</Link>
      </div>
      {data.amendmentOpen ? (
        conference.amendmentClosesAt !== undefined && (
          <Text>
            {t("sponsorships.edit.amendment_availability", {
              ts: t.dateTime(conference.amendmentClosesAt),
            })}
          </Text>
        )
      ) : (
        <Banner
          variant="alert"
          icon={<WarningIcon />}
          title={t("sponsor_ui.applications.amendment_closed")}
        />
      )}
      <ApplicationEditor
        slug={slug}
        conference={conference}
        plans={form.plans}
        description={form.description}
        application={application}
        currentAsset={
          assetFile === undefined
            ? undefined
            : { href: assetFileHref(slug, assetFile.id), extension: assetFile.extension }
        }
        mode={{
          kind: "edit",
          savedPlanId: application.planId,
          accepted: data.accepted,
          readOnly: !data.amendmentOpen,
        }}
      />
    </div>
  );
}
