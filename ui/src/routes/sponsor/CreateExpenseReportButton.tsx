import { Button } from "@cloudflare/kumo";
import { useSWRConfig } from "swr";
import { SponsorService } from "../../gen/rubykaigi/sponsor_app/sponsor_service_pb.ts";
import { useT } from "../../lib/i18n.tsx";
import { useGoTo } from "../../lib/navigation.ts";
import { isRpcKeyOf, useRpcMutation } from "../../lib/rpc.ts";
import { expenseReportPath } from "./shellRedirects.ts";
import { notifyFailure } from "./SponsorRouteError.tsx";

// Starts the sponsorship's expense report, then opens its editor.
export function CreateExpenseReportButton({ slug }: { slug: string }) {
  const t = useT();
  const goTo = useGoTo();
  const { mutate } = useSWRConfig();
  const createReport = useRpcMutation(SponsorService.method.createExpenseReport);

  async function handleCreate() {
    try {
      await createReport.trigger({ conferenceSlug: slug });
    } catch (error) {
      notifyFailure(t, error);
      return;
    }
    await mutate(
      (key) =>
        isRpcKeyOf(key, SponsorService.method.getExpenseReport) ||
        isRpcKeyOf(key, SponsorService.method.getSponsorship),
    );
    goTo(expenseReportPath(slug));
  }

  return (
    <Button
      variant="primary"
      size="sm"
      loading={createReport.isMutating}
      onClick={() => void handleCreate()}
    >
      {t("sponsorships.show.expense_report.create")}
    </Button>
  );
}
