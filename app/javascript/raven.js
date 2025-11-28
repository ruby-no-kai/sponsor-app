import * as Sentry from "@sentry/browser";

if (window.SENTRY_DSN) {
  Sentry.init({
    dsn: window.SENTRY_DSN,
    release: window.APP_VERSION,
    tracesSampleRate: 0.2,
  });
}
