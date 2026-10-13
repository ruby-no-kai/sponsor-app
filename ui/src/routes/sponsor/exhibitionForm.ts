import type { MessageInitShape } from "@bufbuild/protobuf";
import type { Exhibition } from "../../gen/rubykaigi/sponsor_app/exhibition_pb.ts";
import type { ExhibitionInputSchema } from "../../gen/rubykaigi/sponsor_app/sponsor_exhibitions_pb.ts";
import type { FormErrors } from "../../lib/errors.ts";
import type { FieldLayout } from "../../lib/fieldErrors.ts";

// Named after ExhibitionInput's JSON fields, so a google.rpc.BadRequest field path below "input."
// is the name of the form field it concerns.
export type ExhibitionValues = { description: string };

export const EXHIBITION_LAYOUT: FieldLayout = { labels: { description: "description" } };

export function exhibitionValuesFrom(exhibition: Exhibition | undefined): ExhibitionValues {
  return { description: exhibition?.description ?? "" };
}

export function exhibitionInputFrom(
  values: ExhibitionValues,
): MessageInitShape<typeof ExhibitionInputSchema> {
  return { description: values.description };
}

// What the form checks before sending. The server checks again.
export function validateExhibition(
  values: ExhibitionValues,
  messages: { required: string },
): FormErrors | undefined {
  return values.description.trim() === ""
    ? { fields: { description: messages.required } }
    : undefined;
}
