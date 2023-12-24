import Rails from "@rails/ujs";

export interface Ticket {
  id: number;
  code: string;
  kind: string;
  name: string;
  sponsor: string;
  conference: string;
}

export interface TicketCheckinResult {
  ok: boolean;
  ticket: Ticket | null;
  errors?: string[];
}

export async function checkin(url: string) {
  const payload = new FormData();
  payload.append(Rails.csrfParam() || "", Rails.csrfToken() || "");

  const resp = await fetch(url, {
    method: "PUT",
    credentials: "include",
    body: payload,
  });
  if (!resp.ok) {
    if (resp.status == 404) {
      return {
        ok: false,
        errors: ["ticket not found"],
        ticket: null,
      };
    }
    throw new Error(`checkin failed: status=${resp.status}`);
  }
  const result: TicketCheckinResult = await resp.json();
  return result;
}
