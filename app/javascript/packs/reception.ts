import "bootstrap/dist/css/bootstrap";
import "font-awesome/css/font-awesome";

import * as Sentry from "@sentry/react";
import { SENTRY_DSN } from "../meta";

Sentry.init({
  dsn: SENTRY_DSN,
});

import "bootstrap";

import Rails from "@rails/ujs";
Rails.start();

import "../reception_checkin_form";
import "../reception_checkin_button";
