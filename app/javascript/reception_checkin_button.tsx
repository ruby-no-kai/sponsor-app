import React from "react";
import ReactDOM from "react-dom";

import ReceptionCheckinButton from "./ReceptionCheckinButton";

document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".checkin_button").forEach((target) => {
    const elem = target as HTMLDivElement;
    const endpoint = elem.dataset.ticketUrl;
    if (!endpoint) return;
    const component = ReactDOM.render(
      <ReceptionCheckinButton endpoint={endpoint} />,
      target,
    ) as unknown as ReceptionCheckinButton;
  });
});
