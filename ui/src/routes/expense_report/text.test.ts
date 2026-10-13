import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ExpenseReport_Status } from "../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import { translator } from "../../lib/translator.ts";
import { ADMIN_EDITOR_TEXT, ADMIN_TRANSLATIONS } from "./adminText.ts";
import {
  editorText,
  EDITOR_SCOPE,
  formatDay,
  PLAIN_KEYS,
  PLURAL_KEYS,
  SPA_KEYS,
  SPA_SCOPE,
  statusKey,
  textKey,
} from "./text.ts";

describe("the staff area's English table", () => {
  it("holds every text the editor reads", () => {
    for (const key of [...PLAIN_KEYS, ...SPA_KEYS]) {
      assert.ok(textKey(key) in ADMIN_TRANSLATIONS, key);
    }
    for (const key of PLURAL_KEYS) {
      assert.ok(`${textKey(key)}.one` in ADMIN_TRANSLATIONS, key);
      assert.ok(`${textKey(key)}.other` in ADMIN_TRANSLATIONS, key);
    }
  });

  it("names every status the editor shows", () => {
    for (const status of [
      ExpenseReport_Status.DRAFT,
      ExpenseReport_Status.SUBMITTED,
      ExpenseReport_Status.APPROVED,
      ExpenseReport_Status.REJECTED,
    ]) {
      assert.ok(statusKey(status) in ADMIN_TRANSLATIONS, statusKey(status));
    }
  });

  it("fills in variables and picks a plural form", () => {
    assert.equal(ADMIN_EDITOR_TEXT("saved", { title: "Venue" }), "Saved Venue");
    assert.equal(
      ADMIN_EDITOR_TEXT("fields_need_attention", { count: 1, field: "Title", message: "blank" }),
      "Title: blank",
    );
    assert.equal(
      ADMIN_EDITOR_TEXT("fields_need_attention", { count: 2, field: "Title", message: "blank" }),
      "2 fields need attention, starting with Title: blank",
    );
    assert.equal(ADMIN_EDITOR_TEXT.status(ExpenseReport_Status.REJECTED), "rejected");
  });
});

describe("textKey", () => {
  it("reads the SPA's own texts from their scope and the others from the editor's", () => {
    assert.equal(textKey("save"), `${EDITOR_SCOPE}.save`);
    assert.equal(textKey("duplicate_keep_files"), `${SPA_SCOPE}.duplicate_keep_files`);
    assert.equal(textKey("preliminal_badge"), `${SPA_SCOPE}.preliminal_badge`);
  });
});

describe("formatDay", () => {
  it("names the month and day in the language", () => {
    const date = new Date("2026-10-14T03:00:00Z");
    assert.equal(formatDay(date, "en", "Asia/Tokyo"), "Oct 14");
    assert.equal(formatDay(date, "ja", "Asia/Tokyo"), "10月14日");
  });
});

describe("editorText", () => {
  it("reads the editor's scope of the translations it is given", () => {
    const text = editorText(
      translator({
        locale: "ja",
        orgName: "Ruby no Kai",
        translations: {
          [`${EDITOR_SCOPE}.save`]: "保存",
          [`${EDITOR_SCOPE}.drop_to_add`]: "ファイルをドロップするか %{link} して追加",
          [statusKey(ExpenseReport_Status.SUBMITTED)]: "提出済み",
        },
      }),
    );

    assert.equal(text("save"), "保存");
    assert.equal(text.status(ExpenseReport_Status.SUBMITTED), "提出済み");
  });
});
