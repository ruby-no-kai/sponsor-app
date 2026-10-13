import { Loader } from "@cloudflare/kumo";
import { useParams } from "react-router";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";
import { SponsorEventBack } from "./SponsorEventParts.tsx";
import { SponsorEventEditor } from "./SponsorEventEditor.tsx";
import { eventIdFromParam, eventPath } from "./sponsorEventPaths.ts";
import { isNotFound, preconditionMessage } from "./sponsorSave.ts";
import { SponsorNotFound } from "./SponsorRouteError.tsx";

// Changes an event, until it is withdrawn or the conference stops taking event submissions.
export default function EditSponsorEvent() {
  const { slug = "", id: param } = useParams();
  const t = useT();
  const id = eventIdFromParam(param);
  const request = { conferenceSlug: slug, id: id ?? 0n };
  const form = useRpc(
    SponsorService.method.getSponsorEventForm,
    id === undefined ? null : { conferenceSlug: slug },
  );
  const event = useRpc(SponsorService.method.getSponsorEvent, id === undefined ? null : request);
  useDocumentTitle(t("sponsor_events.edit.title"), event.data?.conference?.name);

  if (id === undefined) return <SponsorNotFound />;
  const error = event.error ?? form.error;
  if (error !== undefined && isNotFound(error)) return <SponsorNotFound />;
  const unmet = error === undefined ? undefined : preconditionMessage(error);
  if (unmet !== undefined) return <SponsorEventBack slug={slug} message={unmet} />;
  if (error !== undefined && (event.data === undefined || form.data === undefined)) throw error;
  if (event.data === undefined || form.data === undefined) return <Loader size="lg" />;

  const { sponsorEvent } = event.data;
  if (sponsorEvent === undefined) throw new Error("GetSponsorEvent returned no event");
  if (!form.data.submissionOpen) {
    return <SponsorEventBack slug={slug} message={t("sponsor_events.event_submission_not_open")} />;
  }
  if (!sponsorEvent.editable) {
    return (
      <SponsorEventBack
        slug={slug}
        message={t("sponsor_events.edit.withdrawn_not_editable")}
        back={{ href: eventPath(slug, id), label: t("sponsor_events.show.title") }}
      />
    );
  }
  return <SponsorEventEditor slug={slug} texts={form.data} event={sponsorEvent} />;
}
