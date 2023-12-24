import * as Sentry from "@sentry/browser";

if (window.SENTRY_DSN) {
  Sentry.init({ dsn: window.SENTRY_DSN });
}
