import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { useRpc } from "../../lib/rpc.ts";
import { useDocumentTitle } from "../../lib/title.ts";

// The name of a conference from the list the sidebar loads, or its slug while that loads.
export function useConferenceName(slug: string): string {
  const { data } = useRpc(AdminService.method.listConferences, {});
  return (
    data?.conferences.find((entry) => entry.conference?.slug === slug)?.conference?.name ?? slug
  );
}

// Titles a screen of a conference after the conference's name.
export function useConferenceTitle(slug: string, ...parts: (string | undefined)[]): void {
  useDocumentTitle(...parts, useConferenceName(slug));
}
