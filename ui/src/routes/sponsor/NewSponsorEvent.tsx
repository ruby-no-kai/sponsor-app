import { Loader } from "@cloudflare/kumo";
import { useParams } from "react-router";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { SponsorEventBack } from "./SponsorEventParts.tsx";
import { SponsorEventEditor } from "./SponsorEventEditor.tsx";
import { preconditionMessage } from "./sponsorSave.ts";

// Submits an event, while the conference takes event submissions.
export default function NewSponsorEvent() {
  const { slug = "" } = useParams();
  const t = useT();
  const { data, error } = useRpc(SponsorService.method.getSponsorEventForm, {
    conferenceSlug: slug,
  });
  useDocumentTitle(t("sponsor_events.new.title"), data?.conference?.name);

  const unmet = error === undefined ? undefined : preconditionMessage(error);
  if (unmet !== undefined) return <SponsorEventBack slug={slug} message={unmet} />;
  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  if (!data.submissionOpen) {
    return <SponsorEventBack slug={slug} message={t("sponsor_events.event_submission_not_open")} />;
  }
  return <SponsorEventEditor slug={slug} texts={data} event={undefined} />;
}
