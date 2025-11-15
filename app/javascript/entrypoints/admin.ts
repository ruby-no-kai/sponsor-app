import "bootstrap/dist/css/bootstrap";
import "font-awesome/css/font-awesome";

// Provide jQuery globally for Bootstrap 4
import jquery from "jquery";
window.$ = window.jQuery = jquery;

import * as Sentry from "@sentry/react";
import { SENTRY_DSN } from "../meta";

Sentry.init({
  dsn: SENTRY_DSN,
});

import "bootstrap";

import Rails from "@rails/ujs";
Rails.start();

import "../user_sponsorships_form";
import "../broadcast_new_recipient_fields";
import "../booth_assignments";
