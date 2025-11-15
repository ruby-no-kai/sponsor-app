import * as Sentry from "@sentry/react";
import { SENTRY_DSN, RELEASE } from "./meta";

Sentry.init({
  dsn: SENTRY_DSN,
  release: RELEASE,
});
