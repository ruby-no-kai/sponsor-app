import React from "react";
import { createRoot } from "react-dom/client";

import AssetFileForm, {
  AssetFileFormAPI,
} from "./AssetFileForm";

declare global {
  interface Window {
    rksSponsorshipAssetFileForms: React.RefObject<AssetFileFormAPI | null>[];
    rksTriggerAllUploads: () => Promise<(string | null)[]>;
  }
}

window.rksSponsorshipAssetFileForms = [];

window.rksTriggerAllUploads = async () => {
  return Promise.all(
    window.rksSponsorshipAssetFileForms.map(
      (ref) => ref.current?.ensureUpload() ?? Promise.resolve(null),
    ),
  );
};

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".sponsorships_form").forEach((formElem) => {
    const form = formElem as HTMLFormElement;
    const errorElem = form.querySelector(".submit_error") as HTMLDivElement;
    form.querySelectorAll(".sponsorships_form_asset_file").forEach((elem_) => {
      const elem = elem_ as HTMLDivElement;
      const dest = elem.querySelector(".sponsorships_form_asset_file_form");

      const fileIdElem = elem.querySelector(
        'input[type=hidden][name="sponsorship[asset_file_id]"]',
      ) as HTMLInputElement;
      const fileIdToCopyElem = elem.querySelector(
        'input[type=hidden][name="sponsorship[asset_file_id_to_copy]"]',
      ) as HTMLInputElement | undefined;
      if (!fileIdElem) return;
      const existingFileId =
        fileIdElem.value.length > 0 ? fileIdElem.value : null;
      const doCopy = (fileIdToCopyElem?.value ?? "").length > 0;

      const sessionEndpoint = elem.dataset.sessionEndpoint;
      const sessionEndpointMethod = elem.dataset.sessionEndpointMethod;
      if (!sessionEndpoint || !sessionEndpointMethod) return;

      const onFileChange = (file: File | null) => {
        console.log("File changed:", file?.type);
        const warningsToShow = new Map<string, boolean>();

        if (
          file?.type === "application/zip" ||
          file?.type === "application/x-zip-compressed" ||
          file?.name.endsWith(".zip")
        ) {
          warningsToShow.set("zip_asset", true);
        }

        const warningElems = form.querySelectorAll<HTMLElement>(
          ".sponsorships_form_asset_file_form__warning",
        );

        warningElems.forEach((w) => {
          if (warningsToShow.has(w.dataset.warningKind || "")) {
            w.classList.remove("d-none");
            w.querySelectorAll("input").forEach((i) => (i.required = true));
          } else {
            w.classList.add("d-none");
            w.querySelectorAll("input").forEach((i) => (i.required = false));
          }
        });
      };

      const componentRef = React.createRef<AssetFileFormAPI>();

      if (!dest) {
        console.error("Destination element not found for AssetFileForm");
        return;
      }

      const root = createRoot(dest);
      root.render(
        <AssetFileForm
          ref={componentRef}
          needUpload={doCopy ? false : !existingFileId}
          existingFileId={existingFileId}
          sessionEndpoint={sessionEndpoint}
          sessionEndpointMethod={sessionEndpointMethod}
          accept="image/svg,image/svg+xml,application/pdf,application/zip,.ai,.eps"
          onFileChange={onFileChange}
        />
      );

      // Add ref to global array - it will be populated when component mounts
      window.rksSponsorshipAssetFileForms.push(componentRef);
      console.log("Registered AssetFileForm (ref will be available after mount)");
      form.addEventListener("submit", async function (e) {
        e.preventDefault();
        form
          .querySelectorAll("input[type=submit]")
          .forEach((el) => ((el as HTMLInputElement).disabled = true));
        try {
          errorElem.classList.add("d-none");
          if (!componentRef.current) {
            throw new Error("AssetFileForm ref is not available");
          }
          const fileId = await componentRef.current.ensureUpload();
          if (fileId !== null) {
            fileIdElem.value = fileId;
            form.submit();
            return;
          }
          form
            .querySelectorAll("input[type=submit]:disabled")
            .forEach((el) => ((el as HTMLInputElement).disabled = false));
        } catch (e) {
          errorElem.innerHTML = `ERROR: ${e}`;
          errorElem.classList.remove("d-none");
          form
            .querySelectorAll("input[type=submit]:disabled")
            .forEach((el) => ((el as HTMLInputElement).disabled = false));
          throw e;
        }
      });
    });
  });
});
