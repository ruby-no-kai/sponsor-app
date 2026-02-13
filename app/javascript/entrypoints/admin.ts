// Provide jQuery globally for Bootstrap 4
import jquery from "jquery";

declare global {
  interface Window {
    $: typeof jquery;
    jQuery: typeof jquery;
  }
}

window.$ = window.jQuery = jquery;

import "../sentry";

import "bootstrap";

import Rails from "@rails/ujs";
Rails.start();

import "../admin_datetime_now";
import "../user_sponsorships_form";
import "../broadcast_new_recipient_fields";
import "../booth_assignments";
