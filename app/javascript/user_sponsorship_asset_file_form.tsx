import React from "react";
import ReactDOM from "react-dom";

import SponsorshipAssetFileForm from './SponsorshipAssetFileForm';

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll('.sponsorships_form').forEach((formElem) => {
    const form = formElem as HTMLFormElement;
    const errorElem = form.querySelector('.submit_error') as HTMLDivElement;
    form.querySelectorAll('.sponsorships_form_asset_file').forEach((elem_) => {
      const elem = elem_ as HTMLDivElement;
      const dest = elem.querySelector('.sponsorships_form_asset_file_form');

      const fileIdElem = elem.querySelector('input[type=hidden]') as HTMLInputElement;
      if (!fileIdElem) return;
      const existingFileId = fileIdElem.value.length > 0 ? fileIdElem.value : null;

      const sessionEndpoint = elem.dataset.sessionEndpoint;
      const sessionEndpointMethod = elem.dataset.sessionEndpointMethod;
      if (!sessionEndpoint || !sessionEndpointMethod) return;

      const component = ReactDOM.render(
        <SponsorshipAssetFileForm
          existingFileId={existingFileId}
          sessionEndpoint={sessionEndpoint}
          sessionEndpointMethod={sessionEndpointMethod}
        />,
      dest) as unknown as SponsorshipAssetFileForm;
      form.addEventListener('submit', async function (e) {
        e.preventDefault();
        form.querySelectorAll('input[type=submit]:disabled').forEach((el) => (el as HTMLInputElement).disabled = true);
        try {
          errorElem.classList.add('d-none');
          const fileId = await component.startUpload();
          if (fileId) {
            fileIdElem.value = fileId;
            form.submit();
            return;
          }
          form.querySelectorAll('input[type=submit]:disabled').forEach((el) => (el as HTMLInputElement).disabled = false);
        } catch (e) {
          errorElem.innerHTML = `ERROR: ${e}`;
          errorElem.classList.remove('d-none');
          form.querySelectorAll('input[type=submit]:disabled').forEach((el) => (el as HTMLInputElement).disabled = false);
          throw e;
        }
      });
    });
  });
});

