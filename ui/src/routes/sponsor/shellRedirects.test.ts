import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import { ConferenceSchema } from "../../gen/rubykaigi/sponsor_app/conference_pb.ts";
import {
  SponsorViewerSchema,
  SponsorViewer_SponsorshipSchema,
} from "../../gen/rubykaigi/sponsor_app/sponsor_viewer_pb.ts";
import { dashboardRedirect, landingRedirect, pickerRedirect } from "./shellRedirects.ts";

const conference = (slug: string) => create(ConferenceSchema, { slug });

const viewerOf = (...slugs: string[]) =>
  create(SponsorViewerSchema, {
    email: "contact@example.com",
    sponsorships: slugs.map((slug, index) =>
      create(SponsorViewer_SponsorshipSchema, {
        id: BigInt(index + 1),
        conference: conference(slug),
      }),
    ),
  });

describe("landingRedirect", () => {
  it("sends a signed-in contact to the conference picker", () => {
    assert.equal(landingRedirect(viewerOf("rubykaigi2048")), "/conferences");
  });

  it("keeps a visitor on the landing page", () => {
    assert.equal(landingRedirect(viewerOf()), undefined);
  });
});

describe("pickerRedirect", () => {
  it("opens the one conference taking applications", () => {
    assert.equal(
      pickerRedirect([conference("rubykaigi2048")], viewerOf("rubykaigi2047")),
      "/conferences/rubykaigi2048/sponsorship",
    );
  });

  it("opens the latest sponsorship when no conference takes applications", () => {
    assert.equal(
      pickerRedirect([], viewerOf("rubykaigi2048", "rubykaigi2047")),
      "/conferences/rubykaigi2048/sponsorship",
    );
  });

  it("lists the conferences when there is a choice, or nothing to open", () => {
    assert.equal(
      pickerRedirect([conference("rubykaigi2048"), conference("kaigionrails2048")], viewerOf()),
      undefined,
    );
    assert.equal(pickerRedirect([], viewerOf()), undefined);
  });
});

describe("dashboardRedirect", () => {
  it("shows the dashboard of a conference the contact sponsors", () => {
    assert.equal(dashboardRedirect(viewerOf("rubykaigi2048"), "rubykaigi2048", ""), undefined);
  });

  it("sends anyone else to the application form, keeping the query", () => {
    assert.equal(
      dashboardRedirect(viewerOf("rubykaigi2047"), "rubykaigi2048", "?invite_code=abc"),
      "/conferences/rubykaigi2048/sponsorship/new?invite_code=abc",
    );
    assert.equal(
      dashboardRedirect(viewerOf(), "rubykaigi2048", ""),
      "/conferences/rubykaigi2048/sponsorship/new",
    );
  });

  it("sends a visitor who is not signed in to sign in, then back", () => {
    assert.equal(
      dashboardRedirect(create(SponsorViewerSchema, {}), "rubykaigi2048", "?hl=ja"),
      "/session/new?back_to=%2Fconferences%2Frubykaigi2048%2Fsponsorship%3Fhl%3Dja",
    );
  });

  it("sends staff without a contact session to the application form", () => {
    assert.equal(
      dashboardRedirect(create(SponsorViewerSchema, { staff: true }), "rubykaigi2048", ""),
      "/conferences/rubykaigi2048/sponsorship/new",
    );
  });
});
