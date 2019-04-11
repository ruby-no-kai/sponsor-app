import React from "react";
import ReactDOM from "react-dom";

import ReceptionCheckinForm from './ReceptionCheckinForm';

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll('.checkin_form').forEach((target) => {
    const elem = target as HTMLDivElement;
    const endpoint = elem.dataset.endpoint;
    if (!endpoint) return;
    const component = ReactDOM.render(
      <ReceptionCheckinForm
        endpoint={endpoint}
      />,
    target) as unknown as ReceptionCheckinForm;
  });
});

