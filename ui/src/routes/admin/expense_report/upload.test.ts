import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import { ExpenseFileUploadSchema } from "../../../gen/rubykaigi/sponsor_app/expense_report_pb.ts";
import {
  extensionOf,
  isAllowedFile,
  sendToStorage,
  sha256Base64,
  storageFormData,
} from "./upload.ts";
import type { Progress } from "./upload.ts";

const upload = create(ExpenseFileUploadSchema, {
  fileId: "5",
  url: "https://storage.example.invalid/bucket",
  fields: { key: "c-1/expenses/s-2/abc--5", "Content-Type": "application/pdf", policy: "p" },
  maxSize: 16n,
});

const file = new File(["%PDF-1.7 receipt"], "receipt.pdf", { type: "application/pdf" });

describe("extensionOf", () => {
  it("takes what follows the last dot", () => {
    assert.equal(extensionOf("receipt.scan.PDF"), "PDF");
    assert.equal(extensionOf("README"), "");
    assert.equal(extensionOf(".hidden"), "");
  });
});

describe("isAllowedFile", () => {
  it("takes the types the server takes", () => {
    assert.ok(isAllowedFile({ type: "image/webp" }));
    assert.ok(!isAllowedFile({ type: "text/html" }));
    assert.ok(!isAllowedFile({ type: "" }));
  });
});

describe("sha256Base64", () => {
  it("digests the file as the storage checks it", async () => {
    const expected = createHash("sha256").update("%PDF-1.7 receipt").digest("base64");

    assert.equal(await sha256Base64(file), expected);
  });
});

describe("storageFormData", () => {
  it("sends the fields, the checksum, then the file last", () => {
    const form = storageFormData(upload, file, "c3Vt");

    assert.deepEqual(
      [...form.keys()],
      [
        "key",
        "Content-Type",
        "policy",
        "x-amz-checksum-algorithm",
        "x-amz-checksum-sha256",
        "file",
      ],
    );
    assert.equal(form.get("x-amz-checksum-sha256"), "c3Vt");
    assert.equal(form.get("x-amz-checksum-algorithm"), "SHA256");
  });

  it("declares the content type when the presigned POST leaves it open", () => {
    const open = create(ExpenseFileUploadSchema, { ...upload, fields: { key: "k" } });

    assert.equal(storageFormData(open, file, "c3Vt").get("Content-Type"), "application/pdf");
  });
});

describe("sendToStorage", () => {
  it("posts the form to the presigned URL and returns the version", async () => {
    const posted: { url: string; form: FormData }[] = [];
    const progress: Progress[] = [];

    const version = await sendToStorage(
      upload,
      file,
      async (url, form, onProgress) => {
        posted.push({ url, form });
        onProgress({ loaded: 16, total: 16 });
        return "v1";
      },
      (step) => progress.push(step),
    );

    assert.equal(version, "v1");
    assert.equal(posted[0]?.url, "https://storage.example.invalid/bucket");
    assert.equal(posted[0]?.form.get("file") instanceof File, true);
    assert.deepEqual(progress, [{ loaded: 16, total: 16 }]);
  });

  it("refuses a file larger than the storage takes before sending it", async () => {
    const large = new File(["x".repeat(17)], "large.pdf", { type: "application/pdf" });

    await assert.rejects(
      sendToStorage(
        upload,
        large,
        () => assert.fail("posted"),
        () => {},
      ),
      /more than the 16 bytes allowed/,
    );
  });
});
