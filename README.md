# SponsorApp2

## Development

```
rails s
yarn run watch
```

- http://localhost:3000/
- http://localhost:3000/admin

### Environment variables

(RubyKaigi organizers: see also https://rubykaigi.esa.io/posts/815)

- `DATABASE_URL`
- `ORG_NAME` Your team name
- `DEFAULT_EMAIL_ADDRESS` Default "From" address for outgoing emails
- `DEFAULT_EMAIL_HOST` Message-ID host part for outgoing emails
- `DEFAULT_URL_HOST` URL host used for outgoing emails

#### AWS

- `S3_FILES_REGION` S3 region name
- `S3_FILES_BUCKET` S3 bucket name
- `S3_FILES_PREFIX` (optional)
- `S3_FILES_ROLE` IAM Role ARN which allows `s3:PutBucket` to all objects on the bucket
  - RubyKaigi staff can use `arn:aws:iam::005216166247:role/SponsorAppDevUser`

You also have to supply a valid AWS credentials to the app in a standard SDK way. RubyKaigi staff refer to https://rubykaigi.org/go/aws for setup access.

#### GitHub

This app requires "GitHub App" with: Repository Metadata (Read-only), Repository Content (Read & Write).
And you need to manually install the app to the repositories.

- `GITHUB_REPO` specify in ":login/:repo" format; used for authorization.
- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET`
- `GITHUB_APP_ID`
- `GITHUB_CLIENT_PRIVATE_KEY` (Base64 encoded DER)
  - `openssl pkey -in /path/to/private-key.pem -outform der | openssl base64 -A`
  - (or concat Base64 part of PEM into a one line)

But during development, you can pass `$BACKDOOR_SECRET` to the application, then go http://localhost:3000/admin/session/new?backdoor=BACKDOOR_SECRET&login=YOUR_GITHUB_LOGIN to login without genuine OAuth2 dance.

#### Slack

- `SLACK_WEBHOOK_URL`

#### Sentry (optional)

- `SENTRY_DSN`

## Roadmap

- [x] Accept application
  - [x] Logo upload
  - [x] Confirmation Email
  - [x] Authentication by one-time email
  - [x] Separate billing contact
  - [x] i18n
  - [x] Unlisted forms
  - [x] Reuse a past application to fill the form
- [ ] Organizer Dashboard
  - [x] Authentication
- [x] Editing history
  - [x] Slack notification
- [x] Sponsor Management
  - [x] Announcements
    - [x] i18n
  - [x] Portal 
  - [x] Additional tickets application
  - [x] Booth details submission
- [x] Sponsor coorination
  - [x] Email Broadcasts
  - [x] Staff notes
  - [x] Manage booth allotments
  - [x] Manage custom sponsorship packages
- [ ] CRM
  - [ ] Manage past applications
  - [ ] GitHub integration
  - [ ] Front integration
  - [ ] Esa integration
- [x] On-site
  - [x] Attendee Registration Desk for sponsorship attendee tickets
- [ ] Invoicing
  - [ ] Export to Google Spreadsheet(?)
- [x] Permissions
  - [x] Staff with restricted access to a specific conference

### Oversights

- [x] profile words limit
- [ ] withdrawing
