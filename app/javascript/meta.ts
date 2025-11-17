export const SENTRY_DSN = document.querySelector<HTMLMetaElement>(
  'meta[name="rk:sentry-dsn"]',
)?.content;

export const RELEASE = document.querySelector<HTMLMetaElement>(
  'meta[name="rk:release"]',
)?.content;
