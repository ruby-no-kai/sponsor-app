import {
  Badge,
  Button,
  Empty,
  LayerCard,
  Link,
  LinkButton,
  Loader,
  Table,
  Text,
} from "@cloudflare/kumo";
import {
  PaperPlaneTiltIcon,
  PencilSimpleIcon,
  PlusIcon,
  TrashIcon,
  UsersIcon,
} from "@phosphor-icons/react";
import { useForm } from "@tanstack/react-form";
import { useState } from "react";
import { generatePath, useParams } from "react-router";
import { useSWRConfig } from "swr";
import { AdminBroadcast_Status } from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import type {
  AdminBroadcast,
  AdminBroadcastDelivery,
} from "../../gen/rubykaigi/sponsor_app/admin_broadcasts_pb.ts";
import { AdminService } from "../../gen/rubykaigi/sponsor_app/admin_service_pb.ts";
import { fieldViolations } from "../../lib/errors.ts";
import { erroredFields, errorsUnder } from "../../lib/fieldErrors.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";
import { formatTimestamp, idFromParam } from "../../lib/forms.ts";
import { useSaveRejection } from "../../lib/rejection.ts";
import { PageHeader } from "../../lib/PageHeader.tsx";
import { isRpcKeyOf, useRpc, useRpcMutation } from "../../lib/rpc.ts";
import { toastManager } from "../../lib/toast.ts";
import { NotFound } from "../RouteError.tsx";
import { paths } from "../paths.ts";
import { ConfirmButton } from "./ConfirmButton.tsx";
import { SaveErrorBanner, Section, useFieldReveal } from "./FormParts.tsx";
import { RecipientFilterFields } from "./RecipientFilterFields.tsx";
import { SandboxedHtml } from "../../lib/SandboxedHtml.tsx";
import { StackedRow, TableOrStack } from "../../lib/StackedRows.tsx";
import {
  BROADCAST_STATUS_LABELS,
  DELIVERY_STATUS_LABELS,
  isBusy,
  refreshIntervalFor,
} from "./broadcastView.ts";
import { useConferenceName, useConferenceTitle } from "./conferenceTitle.ts";
import {
  RECIPIENT_FILTER_LABELS,
  recipientFilterFrom,
  recipientFilterValues,
} from "./recipientFilterForm.ts";
import { labelOf } from "./sponsorshipView.ts";

const ADD_RECIPIENTS_LAYOUT: FieldLayout = { labels: RECIPIENT_FILTER_LABELS };

// Revalidates every broadcast RPC, as each change moves the broadcast's status.
function useRevalidateBroadcasts(): () => Promise<unknown> {
  const { mutate } = useSWRConfig();
  return () =>
    mutate(
      (key) =>
        isRpcKeyOf(key, AdminService.method.getBroadcast) ||
        isRpcKeyOf(key, AdminService.method.listBroadcasts),
    );
}

export default function BroadcastDetail() {
  const { slug = "", id = "" } = useParams();
  const broadcastId = idFromParam(id);
  if (broadcastId === undefined) return <NotFound />;
  return <Detail key={id} slug={slug} id={id} broadcastId={broadcastId} />;
}

function Detail({ slug, id, broadcastId }: { slug: string; id: string; broadcastId: bigint }) {
  const { data, error } = useRpc(
    AdminService.method.getBroadcast,
    { conferenceSlug: slug, broadcastId },
    {
      refreshInterval: (latest) =>
        refreshIntervalFor(latest?.broadcast === undefined ? [] : [latest.broadcast.status]),
    },
  );
  const conferenceName = useConferenceName(slug);
  useConferenceTitle(slug, `Broadcast: ${data?.broadcast?.campaign ?? id}`);

  if (error !== undefined && data === undefined) throw error;
  if (data === undefined) return <Loader size="lg" />;
  const { broadcast, deliveries } = data;
  if (broadcast === undefined) throw new Error("GetBroadcast returned no broadcast");

  const status = labelOf(BROADCAST_STATUS_LABELS, broadcast.status);

  return (
    <div className="flex flex-col gap-4">
      <PageHeader
        crumbs={[
          { label: conferenceName, href: generatePath(paths.conference, { slug }) },
          { label: "Broadcasts", href: generatePath(paths.broadcasts, { slug }) },
        ]}
        title={
          <span className="inline-flex flex-wrap items-center gap-2">
            {broadcast.campaign}
            <Badge variant={status.tone}>{status.text}</Badge>
            {isBusy(broadcast.status) && <Loader size="sm" />}
          </span>
        }
        subtitle={broadcast.description === "" ? undefined : broadcast.description}
        actions={
          <LinkButton
            href={generatePath(paths.broadcastEdit, { slug, id })}
            variant="primary"
            icon={PencilSimpleIcon}
          >
            Edit
          </LinkButton>
        }
      />

      <Section title="Email">
        <Text variant="heading" as="h3">
          {broadcast.title}
        </Text>
        <SandboxedHtml html={broadcast.bodyHtml} title="Body" compact placeholders={["@LOGIN@"]} />
      </Section>

      <Section title={`Recipients (${deliveries.length})`}>
        {broadcast.status === AdminBroadcast_Status.READY ? (
          <AddRecipientsForm slug={slug} broadcast={broadcast} />
        ) : (
          <Text variant="secondary">{recipientsNote(broadcast.status)}</Text>
        )}
        <Deliveries slug={slug} broadcast={broadcast} deliveries={deliveries} />
      </Section>

      <DispatchCard slug={slug} broadcast={broadcast} recipientCount={deliveries.length} />
    </div>
  );
}

function recipientsNote(status: AdminBroadcast_Status): string {
  switch (status) {
    case AdminBroadcast_Status.CREATED:
    case AdminBroadcast_Status.PREPARING:
    case AdminBroadcast_Status.MODIFYING:
      return "Collecting recipients. Recipients can be added again once the broadcast is ready.";
    default:
      return "The broadcast has been dispatched, so its recipients can no longer change.";
  }
}

function AddRecipientsForm({ slug, broadcast }: { slug: string; broadcast: AdminBroadcast }) {
  const addRecipients = useRpcMutation(AdminService.method.addBroadcastRecipients);
  const revalidate = useRevalidateBroadcasts();
  // The error of the last request, for its code and request ID.
  const [saveError, setSaveError] = useState<unknown>();
  const { formRef, reveal } = useFieldReveal();
  const rejection = useSaveRejection();

  const form = useForm({
    defaultValues: { recipientFilter: recipientFilterValues("currentSponsors") },
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      try {
        await addRecipients.trigger({
          conferenceSlug: slug,
          broadcastId: broadcast.id,
          recipientFilter: recipientFilterFrom(value.recipientFilter),
        });
      } catch (error) {
        setSaveError(error);
        rejection.reject(formApi, value, fieldViolations(error));
        const [first] = erroredFields(formApi.state.fieldMeta, ADD_RECIPIENTS_LAYOUT);
        if (first !== undefined) reveal(first.path);
        return;
      }
      setSaveError(undefined);
      toastManager.add({ variant: "success", title: "Adding the recipients" });
      formApi.reset();
      await revalidate();
    },
  });

  return (
    <form
      ref={formRef}
      className="flex flex-col gap-4"
      noValidate
      onSubmit={(event) => {
        event.preventDefault();
        void rejection.submit(form);
      }}
    >
      <form.Field name="recipientFilter">
        {(field) => (
          <form.Subscribe selector={(state) => errorsUnder(state.fieldMeta, field.name)}>
            {(errors) => (
              <RecipientFilterFields
                slug={slug}
                path={field.name}
                value={field.state.value}
                onChange={field.handleChange}
                errors={errors}
                allowNone={false}
              />
            )}
          </form.Subscribe>
        )}
      </form.Field>
      <form.Subscribe
        selector={(state) => ({
          formError: state.errorMap.onChange,
          errored: erroredFields(state.fieldMeta, ADD_RECIPIENTS_LAYOUT),
          isSubmitting: state.isSubmitting,
        })}
      >
        {({ formError, errored, isSubmitting }) => (
          <div className="flex flex-col gap-3">
            <SaveErrorBanner
              formError={formError}
              errored={errored}
              error={saveError}
              onShow={reveal}
            />
            <div>
              <Button type="submit" variant="secondary" icon={PlusIcon} loading={isSubmitting}>
                Add recipients
              </Button>
            </div>
          </div>
        )}
      </form.Subscribe>
    </form>
  );
}

function Deliveries({
  slug,
  broadcast,
  deliveries,
}: {
  slug: string;
  broadcast: AdminBroadcast;
  deliveries: readonly AdminBroadcastDelivery[];
}) {
  if (deliveries.length === 0) {
    return (
      <Empty
        icon={<UsersIcon size={32} />}
        title="No recipients"
        description="Nobody gets this broadcast yet."
      />
    );
  }

  return (
    <TableOrStack
      stack={deliveries.map((delivery) => (
        <DeliveryStackedRow
          key={delivery.id.toString()}
          slug={slug}
          broadcast={broadcast}
          delivery={delivery}
        />
      ))}
      table={
        <Table>
          <Table.Header>
            <Table.Row>
              <Table.Head>Name</Table.Head>
              <Table.Head>Email</Table.Head>
              <Table.Head>Status</Table.Head>
              <Table.Head />
            </Table.Row>
          </Table.Header>
          <Table.Body>
            {deliveries.map((delivery) => (
              <DeliveryRow
                key={delivery.id.toString()}
                slug={slug}
                broadcast={broadcast}
                delivery={delivery}
              />
            ))}
          </Table.Body>
        </Table>
      }
    />
  );
}

type DeliveryProps = { slug: string; broadcast: AdminBroadcast; delivery: AdminBroadcastDelivery };

function DeliveryRow({ slug, broadcast, delivery }: DeliveryProps) {
  return (
    <Table.Row>
      <Table.Cell>
        <DeliveryName slug={slug} delivery={delivery} />
      </Table.Cell>
      <Table.Cell>
        <DeliveryEmail delivery={delivery} />
      </Table.Cell>
      <Table.Cell>
        <DeliveryStatus delivery={delivery} />
      </Table.Cell>
      <Table.Cell>
        <RemoveDelivery slug={slug} broadcast={broadcast} delivery={delivery} />
      </Table.Cell>
    </Table.Row>
  );
}

function DeliveryStackedRow({ slug, broadcast, delivery }: DeliveryProps) {
  return (
    <StackedRow>
      <div className="flex items-start justify-between gap-2">
        <div className="min-w-0">
          <DeliveryName slug={slug} delivery={delivery} />
        </div>
        <RemoveDelivery slug={slug} broadcast={broadcast} delivery={delivery} />
      </div>
      <DeliveryEmail delivery={delivery} />
      <div>
        <DeliveryStatus delivery={delivery} />
      </div>
    </StackedRow>
  );
}

function DeliveryName({ slug, delivery }: { slug: string; delivery: AdminBroadcastDelivery }) {
  const { sponsorship } = delivery;
  if (sponsorship === undefined) return <Text variant="secondary">{delivery.email}</Text>;
  return (
    <div className="flex flex-col">
      <Link
        href={generatePath(paths.sponsorship, {
          slug: sponsorship.conferenceSlug,
          id: sponsorship.id.toString(),
        })}
      >
        {sponsorship.name}
      </Link>
      {sponsorship.conferenceSlug !== slug && (
        <Text variant="secondary" size="sm">
          {sponsorship.conferenceSlug}
        </Text>
      )}
    </div>
  );
}

function DeliveryEmail({ delivery }: { delivery: AdminBroadcastDelivery }) {
  return (
    <div className="flex min-w-0 flex-col break-all">
      <span>{delivery.email}</span>
      {delivery.ccEmails.length > 0 && (
        <Text variant="secondary" size="sm">
          CC: {delivery.ccEmails.join(", ")}
        </Text>
      )}
    </div>
  );
}

function DeliveryStatus({ delivery }: { delivery: AdminBroadcastDelivery }) {
  const status = labelOf(DELIVERY_STATUS_LABELS, delivery.status);
  return <Badge variant={status.tone}>{status.text}</Badge>;
}

function RemoveDelivery({ slug, broadcast, delivery }: DeliveryProps) {
  const removeDelivery = useRpcMutation(AdminService.method.removeBroadcastDelivery);
  const revalidate = useRevalidateBroadcasts();
  if (!delivery.removable) return null;
  return (
    <ConfirmButton
      label="Remove recipient"
      icon={TrashIcon}
      iconOnly
      size="sm"
      title={`Remove ${delivery.email}?`}
      description={`They will not get "${broadcast.title}". They can be added again before dispatch.`}
      confirmLabel="Remove"
      onConfirm={async () => {
        await removeDelivery.trigger({
          conferenceSlug: slug,
          broadcastId: broadcast.id,
          deliveryId: delivery.id,
        });
        await revalidate();
      }}
    />
  );
}

function DispatchCard({
  slug,
  broadcast,
  recipientCount,
}: {
  slug: string;
  broadcast: AdminBroadcast;
  recipientCount: number;
}) {
  const dispatchBroadcast = useRpcMutation(AdminService.method.dispatchBroadcast);
  const revalidate = useRevalidateBroadcasts();
  const isReady = broadcast.status === AdminBroadcast_Status.READY;
  const canDispatch = isReady && recipientCount > 0;
  const sendLabel = `Send to ${recipientCount} ${recipientCount === 1 ? "recipient" : "recipients"}`;

  if (broadcast.dispatchedAt !== undefined) {
    return <Text variant="secondary">Dispatched {formatTimestamp(broadcast.dispatchedAt)}</Text>;
  }

  return (
    <LayerCard className="border-kumo-danger">
      <LayerCard.Secondary>Dispatch</LayerCard.Secondary>
      <LayerCard.Primary className="flex flex-col gap-3">
        <Text variant="secondary">
          Emails go out in the background and cannot be recalled. The title and body are fixed once
          sent.
        </Text>
        <div className="flex flex-wrap items-center gap-3">
          {canDispatch ? (
            <ConfirmButton
              label={sendLabel}
              icon={PaperPlaneTiltIcon}
              title={`Send "${broadcast.title}" now?`}
              description={`It goes to ${recipientCount} ${recipientCount === 1 ? "recipient" : "recipients"} in the background. Sent emails cannot be recalled, and the title and body are fixed from now on.`}
              confirmLabel="Send"
              onConfirm={async () => {
                const response = await dispatchBroadcast.trigger({
                  conferenceSlug: slug,
                  broadcastId: broadcast.id,
                });
                toastManager.add({
                  variant: "success",
                  title: `Dispatched the broadcast ${response.broadcast?.campaign ?? broadcast.campaign}`,
                });
                await revalidate();
              }}
            />
          ) : (
            <>
              <Button variant="destructive" icon={PaperPlaneTiltIcon} disabled>
                {sendLabel}
              </Button>
              <Text variant="secondary">
                {isReady
                  ? "Add recipients first."
                  : `The broadcast is ${labelOf(BROADCAST_STATUS_LABELS, broadcast.status).text}, not ready.`}
              </Text>
            </>
          )}
        </div>
      </LayerCard.Primary>
    </LayerCard>
  );
}
