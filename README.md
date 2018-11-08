# SponsorApp2

## Development

```
rails s
./bin/webpack --watch
```

- http://sponsorships.lo.sorah.jp:3000/
- http://admin.lo.sorah.jp:3000/
  - Development Backdoor access: http://admin.lo.sorah.jp:3000/session/new?login=your-github-login

### Enviroment variables

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
  - You also have to supply a valid AWS credentials to the app in a standard SDK way, e.g. IAM instance profile, ECS task IAM role, and `ENV['AWS_ACCESS_KEY_ID']`.

#### GitHub

This app requires "GitHub App" with: Repository Metadata (Read-only), Repository Content (Read & Write).
And you need to manually install the app to the repositories.

- `GITHUB_REPO` specify in ":login/:repo" format; used for authorization.
- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET`
- `GITHUB_CLIENT_PRIVATE_KEY`

## Roadmap

- [x] Accept application
  - [x] Logo upload
  - [x] Confirmation Email
  - [x] Authentication
- [ ] Organizer Dashboard
  - [x] Authentication
- [ ] Editing history
- [ ] Sponsor Portal
  - [ ] Announcements
  - [ ] Additional tickets submission
  - [ ] Booth details submission (?)
- [ ] CRM
  - [ ] GitHub integration
  - [ ] Front integration
  - [ ] Esa integration
- [ ] Invoicing
  - [ ] Export to Google Spreadsheet(?)

### Oversights

- [ ] profile words limit
- [ ] withdrawing
