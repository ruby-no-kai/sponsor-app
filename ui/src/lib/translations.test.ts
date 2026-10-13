import assert from "node:assert/strict";
import { describe, it } from "node:test";
import {
  formatDateTime,
  pluralKey,
  splitTemplate,
  translate,
  translateHtml,
} from "./translations.ts";

const TRANSLATIONS = {
  "layouts.application.login": "Log in",
  "root.index.sponsor_conference": "Sponsor %{conference}",
  "sponsorships.show.guests_count.zero": "no guests",
  "sponsorships.show.guests_count.one": "1 guest",
  "sponsorships.show.guests_count.other": "%{count} guests",
  "sponsorships.show.tickets.quantity.one": "%{count} pass",
  "sponsorships.show.tickets.quantity.other": "%{count} passes",
  "broadcasts.index.note_html": "Write to <b>%{contact_email}</b>.",
  "broadcasts.index.plain": "Write to <b>%{contact_email}</b>.",
};

describe("translate", () => {
  it("fills in variables", () => {
    assert.equal(
      translate(TRANSLATIONS, "root.index.sponsor_conference", { conference: "RubyKaigi 2048" }),
      "Sponsor RubyKaigi 2048",
    );
  });

  it("leaves a variable without a value as written", () => {
    assert.equal(translate(TRANSLATIONS, "root.index.sponsor_conference"), "Sponsor %{conference}");
  });

  it("renders a missing text as its key", () => {
    assert.equal(
      translate(TRANSLATIONS, "layouts.application.logout"),
      "layouts.application.logout",
    );
  });

  it("picks the plural form by count as I18n does", () => {
    const guests = (count: number) =>
      translate(TRANSLATIONS, "sponsorships.show.guests_count", { count });
    assert.equal(guests(0), "no guests");
    assert.equal(guests(1), "1 guest");
    assert.equal(guests(3), "3 guests");

    const passes = (count: number) =>
      translate(TRANSLATIONS, "sponsorships.show.tickets.quantity", { count });
    assert.equal(passes(0), "0 passes");
    assert.equal(passes(1), "1 pass");
  });
});

describe("pluralKey", () => {
  it("uses the zero form only where the text has one", () => {
    assert.equal(
      pluralKey(TRANSLATIONS, "sponsorships.show.guests_count", 0),
      "sponsorships.show.guests_count.zero",
    );
    assert.equal(
      pluralKey(TRANSLATIONS, "sponsorships.show.tickets.quantity", 0),
      "sponsorships.show.tickets.quantity.other",
    );
  });
});

describe("splitTemplate", () => {
  it("cuts a text at its variables", () => {
    assert.deepEqual(splitTemplate("See %{link} or %{other}."), [
      { text: "See " },
      { variable: "link" },
      { text: " or " },
      { variable: "other" },
      { text: "." },
    ]);
    assert.deepEqual(splitTemplate("%{link}"), [{ variable: "link" }]);
  });
});

describe("translateHtml", () => {
  it("keeps the markup of an _html text and escapes its variables", () => {
    assert.equal(
      translateHtml(TRANSLATIONS, "broadcasts.index.note_html", {
        contact_email: "<x>@example.invalid",
      }),
      "Write to <b>&lt;x&gt;@example.invalid</b>.",
    );
  });

  it("escapes any other text whole", () => {
    assert.equal(
      translateHtml(TRANSLATIONS, "broadcasts.index.plain", { contact_email: "a@example.invalid" }),
      "Write to &lt;b&gt;a@example.invalid&lt;/b&gt;.",
    );
    assert.equal(translateHtml(TRANSLATIONS, "<missing>"), "&lt;missing&gt;");
  });
});

describe("formatDateTime", () => {
  it("names the time zone it shows the time in", () => {
    const date = new Date("2048-04-15T01:30:00Z");
    assert.match(formatDateTime(date, "en", "Asia/Tokyo"), /Apr 15, 2048.*10:30.*GMT\+9/);
    assert.match(formatDateTime(date, "en", "UTC"), /1:30.*UTC/);
  });
});
