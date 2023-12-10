local utils = import './utils.libsonnet';
local secret = utils.makeSecretParameterStore('sponsor-app');

{
  scheduler: {
    task_role_arn: utils.iamRole('SponsorApp'),
  },
  app: {
    image: utils.ecrRepository('sponsor-app'),
    //cpu: 512 - 64,
    //memory: 1024 - 128,
    //cpu: 256 - 64,
    //memory: 512 - 128,
    env: {
      LANG: 'C.UTF-8',
      AWS_REGION: 'us-west-2',
      RACK_ENV: 'production',
      RAILS_ENV: 'production',
      RAILS_LOG_TO_STDOUT: '1',
      RAILS_SERVE_STATIC_FILES: '1',
      WEB_CONCURRENCY: '0',
      RAILS_MAX_THREADS: '5',

      DATABASE_URL: 'postgres://sponsor-app:@ep-restless-haze-08597983.us-west-2.aws.neon.tech/sponsor-app-prd?sslmode=verify-full&sslrootcert=/etc/ssl/certs/ca-certificates.crt',

      ENABLE_SHORYUKEN: '1',
      SPONSOR_APP_SHORYUKEN_QUEUE: 'sponsor-app-activejob-prd',

      DEFAULT_EMAIL_ADDRESS: 'prd@sponsorships.rubykaigi.org',
      DEFAULT_EMAIL_HOST: 'sponsorships.rubykaigi.org',
      DEFAULT_EMAIL_REPLY_TO: 'sponsorships@rubykaigi.org',
      DEFAULT_URL_HOST: 'sponsorships.rubykaigi.org',
      MAILGUN_DOMAIN: 'sponsorships.rubykaigi.org',
      MAILGUN_SMTP_LOGIN: 'postmaster@sponsorships.rubykaigi.org',
      MAILGUN_SMTP_PORT: '587',
      MAILGUN_SMTP_SERVER: 'smtp.mailgun.org',

      GITHUB_APP_ID: '20598',
      GITHUB_CLIENT_ID: 'Iv1.94fc104fb1066d82',
      GITHUB_REPO: 'ruby-no-kai/rubykaigi.org',

      ORG_NAME: 'RubyKaigi',

      S3_FILES_REGION: 'ap-northeast-1',
      S3_FILES_BUCKET: 'rk-sponsorship-files-prd',
      S3_FILES_ROLE: 'arn:aws:iam::005216166247:role/SponsorAppUser',

      SENTRY_DSN: 'https://377e47f99dc740a88afc746c48f6bcd3@sentry.io/1329978',
    },
    secrets: [
      secret('DATABASE_PASSWORD'),
      secret('SECRET_KEY_BASE'),
      secret('GITHUB_CLIENT_PRIVATE_KEY'),
      secret('GITHUB_CLIENT_SECRET'),
      secret('MAILGUN_API_KEY'),
      secret('MAILGUN_SMTP_PASSWORD'),
      secret('SLACK_WEBHOOK_URL'),
      secret('SLACK_WEBHOOK_URL_FOR_FEED'),
      secret('TITO_API_TOKEN'),
    ],
    mount_points: [
    ],
    log_configuration: utils.awsLogs('app'),
  },
  volumes: {
  },
  scripts: [
    // utils.githubTag('') {
    //   checks: [''],
    // },
  ],
}
