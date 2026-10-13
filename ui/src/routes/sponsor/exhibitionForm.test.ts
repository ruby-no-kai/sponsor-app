import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import { ExhibitionSchema } from "../../gen/rubykaigi/sponsor_app/exhibition_pb.ts";
import { exhibitionInputFrom, exhibitionValuesFrom, validateExhibition } from "./exhibitionForm.ts";

describe("exhibitionValuesFrom", () => {
  it("starts empty without booth details", () => {
    assert.deepEqual(exhibitionValuesFrom(undefined), { description: "" });
  });

  it("starts from the saved description", () => {
    const exhibition = create(ExhibitionSchema, { description: "Ruby on a bench" });
    assert.deepEqual(exhibitionValuesFrom(exhibition), { description: "Ruby on a bench" });
  });
});

describe("validateExhibition", () => {
  const messages = { required: "required" };

  it("asks for a description", () => {
    assert.deepEqual(validateExhibition({ description: " \n" }, messages), {
      fields: { description: "required" },
    });
  });

  it("accepts a description", () => {
    assert.equal(validateExhibition({ description: "Ruby" }, messages), undefined);
  });
});

describe("exhibitionInputFrom", () => {
  it("sends the description as typed", () => {
    assert.deepEqual(exhibitionInputFrom({ description: " Ruby\n" }), { description: " Ruby\n" });
  });
});
