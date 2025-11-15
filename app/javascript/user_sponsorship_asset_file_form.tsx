import React from "react";
import ReactDOM from "react-dom";

import SponsorshipAssetFileForm, {
  SponsorshipAssetFileFormAPI,
} from "./SponsorshipAssetFileForm";

declare global {
  interface Window {
    rksSponsorshipAssetFileForms: React.RefObject<SponsorshipAssetFileFormAPI>[];
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

      const componentRef = React.createRef<SponsorshipAssetFileFormAPI>();
      ReactDOM.render(
        <SponsorshipAssetFileForm
          ref={componentRef}
          needUpload={doCopy ? false : !existingFileId}
          existingFileId={existingFileId}
          sessionEndpoint={sessionEndpoint}
          sessionEndpointMethod={sessionEndpointMethod}
        />,
        dest,
      );
      if (componentRef.current) {
        console.log("Mounted SponsorshipAssetFileForm", componentRef.current);
        window.rksSponsorshipAssetFileForms.push(componentRef);
      }
      form.addEventListener("submit", async function (e) {
        e.preventDefault();
        form
          .querySelectorAll("input[type=submit]:disabled")
          .forEach((el) => ((el as HTMLInputElement).disabled = true));
        try {
          errorElem.classList.add("d-none");
          if (!componentRef.current) {
            throw new Error("SponsorshipAssetFileForm ref is not available");
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
