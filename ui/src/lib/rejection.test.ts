import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { FieldApi, FormApi } from "@tanstack/react-form";
import { SaveRejection, standingErrors, valueAt } from "./rejection.ts";

describe("valueAt", () => {
  it("follows names and indices", () => {
    const values = { options: [{ value: "a" }, { value: "b", plans: ["Gold"] }] };
    assert.equal(valueAt(values, "options[1].value"), "b");
    assert.deepEqual(valueAt(values, "options[1].plans"), ["Gold"]);
    assert.equal(valueAt(values, "options[2].value"), undefined);
  });
});

describe("standingErrors", () => {
  const rejected = {
    values: { name: "", options: [{ value: "a", plans: ["Gold"] }] },
    errors: {
      form: "permission denied",
      fields: { name: "is required", "options[0].plans": "names no plan" },
    },
  };

  it("keeps a field's error while it holds the value refused", () => {
    assert.deepEqual(standingErrors(rejected, structuredClone(rejected.values)), rejected.errors);
  });

  it("drops a field's error once its value changes, and keeps the form-level message", () => {
    assert.deepEqual(
      standingErrors(rejected, {
        name: "Gold",
        options: [{ value: "a", plans: ["Gold", "Ruby"] }],
      }),
      { form: "permission denied", fields: {} },
    );
  });

  it("has nothing without a refused save", () => {
    assert.equal(standingErrors(undefined, rejected.values), undefined);
  });
});

type Values = { name: string; slug: string };

// A form wired as the editors wire theirs, with a save the server refuses until the slug changes.
function editor() {
  const rejection = new SaveRejection();
  const sent: Values[] = [];
  const saved: Values[] = [];
  const form = new FormApi<Values, any, any, any, any, any, any, any, any, any, any, any>({
    defaultValues: { name: "RubyKaigi", slug: "taken" },
    validators: { onChange: rejection.validate },
    onSubmit: async ({ value, formApi }) => {
      sent.push(value);
      if (value.slug === "taken") {
        rejection.reject(formApi, value, { fields: { slug: "has already been taken" } });
        return;
      }
      saved.push(value);
    },
  });
  form.mount();
  const fields = {
    name: new FieldApi({ form, name: "name" }),
    slug: new FieldApi({ form, name: "slug" }),
  };
  fields.name.mount();
  fields.slug.mount();
  return { form, fields, rejection, sent, saved };
}

describe("SaveRejection", () => {
  it("keeps a refused field's error through a blur", async () => {
    const { form, fields, rejection } = editor();
    await rejection.submit(form);
    assert.deepEqual(fields.slug.state.meta.errors, ["has already been taken"]);

    fields.slug.handleBlur();
    fields.name.handleBlur();
    assert.deepEqual(fields.slug.state.meta.errors, ["has already been taken"]);
  });

  it("clears a field's error when its value changes, and only that field's", async () => {
    const { form, fields, rejection } = editor();
    await rejection.submit(form);

    fields.name.handleChange("RubyKaigi 2048");
    assert.deepEqual(fields.slug.state.meta.errors, ["has already been taken"]);
    fields.slug.handleChange("rubykaigi2048");
    assert.deepEqual(fields.slug.state.meta.errors, []);
  });

  it("sends the form again while the last save's errors stand", async () => {
    const { form, fields, rejection, sent, saved } = editor();
    await rejection.submit(form);
    await rejection.submit(form);
    assert.equal(sent.length, 2);

    fields.slug.handleBlur();
    form.setFieldValue("slug", "rubykaigi2048", { dontValidate: true });
    await rejection.submit(form);
    assert.equal(sent.length, 3);
    assert.deepEqual(saved, [{ name: "RubyKaigi", slug: "rubykaigi2048" }]);
    assert.deepEqual(fields.slug.state.meta.errors, []);
  });

  it("attaches an error to the values sent, not to ones typed while the save was in flight", async () => {
    const rejection = new SaveRejection();
    let sent: () => void = () => {};
    const sending = new Promise<void>((resolve) => (sent = resolve));
    let answer: () => void = () => {};
    const answered = new Promise<void>((resolve) => (answer = resolve));
    const form = new FormApi<Values, any, any, any, any, any, any, any, any, any, any, any>({
      defaultValues: { name: "RubyKaigi", slug: "taken" },
      validators: { onChange: rejection.validate },
      onSubmit: async ({ value, formApi }) => {
        sent();
        await answered;
        rejection.reject(formApi, value, { fields: { slug: "has already been taken" } });
      },
    });
    form.mount();
    const slug = new FieldApi({ form, name: "slug" });
    slug.mount();

    const saving = rejection.submit(form);
    await sending;
    slug.handleChange("rubykaigi2048");
    answer();
    await saving;
    assert.deepEqual(slug.state.meta.errors, []);

    slug.handleChange("taken");
    assert.deepEqual(slug.state.meta.errors, ["has already been taken"]);
  });

  it("keeps a form-level message until the next save", async () => {
    const rejection = new SaveRejection();
    const form = new FormApi<Values, any, any, any, any, any, any, any, any, any, any, any>({
      defaultValues: { name: "RubyKaigi", slug: "rubykaigi2048" },
      validators: { onChange: rejection.validate },
      onSubmit: ({ value, formApi }) =>
        rejection.reject(formApi, value, { form: "permission denied", fields: {} }),
    });
    form.mount();
    const name = new FieldApi({ form, name: "name" });
    name.mount();

    await rejection.submit(form);
    name.handleChange("RubyKaigi 2048");
    assert.equal(form.state.errorMap.onChange, "permission denied");
  });
});
