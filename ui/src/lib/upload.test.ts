import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { describe, it } from "node:test";
import { create } from "@bufbuild/protobuf";
import { AssetUploadSchema } from "../gen/rubykaigi/sponsor_app/asset_upload_pb.ts";
import {
  FileTooLargeError,
  UploadOnce,
  extensionOf,
  formatFileSize,
  sendToStorage,
  sha256Base64,
  storageFormData,
  uploadFile,
} from "./upload.ts";
import type { Progress, StoragePost } from "./upload.ts";

describe("formatFileSize", () => {
  it("picks the largest unit that keeps the number small", () => {
    assert.equal(formatFileSize(0), "0 B");
    assert.equal(formatFileSize(420), "420 B");
    assert.equal(formatFileSize(1536), "1.5 KB");
    assert.equal(formatFileSize(2048), "2 KB");
    assert.equal(formatFileSize(12 * 1024 * 1024), "12 MB");
  });
});

const upload = create(AssetUploadSchema, {
  fileId: 5n,
  url: "https://storage.example.invalid/bucket",
  fields: { key: "c-1/abc--5", "Content-Type": "image/svg+xml", policy: "p" },
  maxSize: 16n,
});

const file = new File(["<svg>logo</svg>"], "logo.svg", { type: "image/svg+xml" });

const postReturning =
  (version: string, posted: { url: string; form: FormData }[] = []): StoragePost =>
  async (url, form, onProgress) => {
    posted.push({ url, form });
    onProgress({ loaded: 15, total: 15 });
    return version;
  };

describe("extensionOf", () => {
  it("takes what follows the last dot", () => {
    assert.equal(extensionOf("logo.final.SVG"), "SVG");
    assert.equal(extensionOf("README"), "");
    assert.equal(extensionOf(".hidden"), "");
  });
});

describe("sha256Base64", () => {
  it("digests the file as the storage checks it", async () => {
    const expected = createHash("sha256").update("<svg>logo</svg>").digest("base64");

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

  it("declares the content type only when the presigned POST leaves it open", () => {
    const open = create(AssetUploadSchema, { ...upload, fields: { key: "k" } });

    assert.equal(storageFormData(open, file, "c3Vt").get("Content-Type"), "image/svg+xml");
    assert.deepEqual(storageFormData(upload, file, "c3Vt").getAll("Content-Type"), [
      "image/svg+xml",
    ]);
  });
});

describe("sendToStorage", () => {
  it("posts the form to the presigned URL and returns the version", async () => {
    const posted: { url: string; form: FormData }[] = [];
    const progress: Progress[] = [];

    const version = await sendToStorage(upload, file, postReturning("v1", posted), (step) =>
      progress.push(step),
    );

    assert.equal(version, "v1");
    assert.equal(posted[0]?.url, "https://storage.example.invalid/bucket");
    assert.equal(posted[0]?.form.get("file") instanceof File, true);
    assert.deepEqual(progress, [{ loaded: 15, total: 15 }]);
  });

  it("refuses a file larger than the storage takes before sending it", async () => {
    const large = new File(["x".repeat(17)], "large.svg", { type: "image/svg+xml" });

    await assert.rejects(
      sendToStorage(
        upload,
        large,
        () => assert.fail("posted"),
        () => {},
      ),
      (error) => error instanceof FileTooLargeError && error.maxSize === 16n,
    );
  });
});

describe("uploadFile", () => {
  it("starts, sends and completes the upload, reporting the version and extension", async () => {
    const completed: [bigint, string, string][] = [];

    const fileId = await uploadFile(
      file,
      {
        start: async () => upload,
        complete: async (...args) => completed.push(args),
      },
      { post: postReturning("v2") },
    );

    assert.equal(fileId, 5n);
    assert.deepEqual(completed, [[5n, "v2", "svg"]]);
  });

  it("completes nothing when the storage refuses the file", async () => {
    await assert.rejects(
      uploadFile(
        file,
        {
          start: async () => upload,
          complete: async () => assert.fail("completed"),
        },
        {
          post: async () => {
            throw new Error("refused");
          },
        },
      ),
      /refused/,
    );
  });
});

describe("UploadOnce", () => {
  it("uploads a file once, however often it is ensured", async () => {
    const once = new UploadOnce();
    let uploads = 0;
    const upload = async () => BigInt(++uploads);

    assert.equal(await once.ensure(file, upload), 1n);
    assert.equal(await once.ensure(file, upload), 1n);
    assert.equal(uploads, 1);
  });

  it("uploads again for another file", async () => {
    const once = new UploadOnce();
    let uploads = 0;
    const upload = async () => BigInt(++uploads);
    const other = new File(["<svg/>"], "other.svg", { type: "image/svg+xml" });

    await once.ensure(file, upload);
    assert.equal(await once.ensure(other, upload), 2n);
  });

  it("tries a failed upload afresh", async () => {
    const once = new UploadOnce();
    let attempts = 0;
    const upload = async () => {
      attempts += 1;
      if (attempts === 1) throw new Error("storage down");
      return 7n;
    };

    await assert.rejects(once.ensure(file, upload), /storage down/);
    assert.equal(await once.ensure(file, upload), 7n);
  });
});
