import type { SaveErrorMessages } from "../admin/FormParts.tsx";
import type { EditorText } from "./text.ts";

export function saveErrorMessages(text: EditorText): SaveErrorMessages {
  return {
    title: text("not_saved"),
    show: text("show"),
    fieldsNeedAttention: (count, field, message) =>
      text("fields_need_attention", { count, field, message }),
    requestId: (requestId) => text("request_id", { request_id: requestId }),
  };
}
