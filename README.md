# SendPortal on Railway

One-click [SendPortal](https://github.com/mettle/sendportal) for [Railway](https://railway.com): open-source, self-hosted email marketing (newsletters, campaigns, subscribers, segments, templates and an API), sending through your own Amazon SES, SendGrid, Mailgun, Postmark, Mailjet, Postal or SMTP account.

## What the template deploys

| Service | Source | Notes |
|---|---|---|
| **SendPortal** | this repo (`Dockerfile`) | SendPortal **v4.0.0.1** (Laravel 13, PHP 8.4, Apache). Runs the web app, the Horizon queue workers and the Laravel scheduler in one container under supervisord. Public, health check `/login` |
| **Postgres** | Railway Postgres | All SendPortal data (subscribers, campaigns, templates, messages, users), on a volume |
| **Redis** | Railway Redis | Queue, cache and sessions |

SendPortal ships no official Docker image, so the `Dockerfile` downloads the tagged release from GitHub (checked against its SHA-256), installs the PHP dependencies pinned in `composer.lock`, and builds on the official `php:8.4.27-apache-trixie` image, pinned by digest.

On every start, `railway/start.sh` runs the database migrations, and on the first start `railway/create-admin.php` creates the admin user and workspace from the variables below. The public `/setup` wizard then only redirects to the login page, so nobody else can claim the instance. Sign-up stays closed (`SENDPORTAL_REGISTER=false`): invite more users from **Manage Users**.

## Variables

| Variable | Default | Purpose |
|---|---|---|
| `SENDPORTAL_ADMIN_EMAIL` | *(you enter it)* | Email address of the first admin |
| `SENDPORTAL_ADMIN_PASSWORD` | `${{secret(24)}}` | First admin's password. Read it in the service's Variables tab. Change it later in the app (Profile, Change password); the variable is only used on the first start |
| `APP_KEY` | `${{secret(32)}}` | Laravel encryption key (encrypts the stored email-service credentials). Don't change it after the first start |
| `APP_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL, used in tracking and unsubscribe links. Change it if you add a custom domain |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | Database connection |
| `REDIS_URL` | `${{Redis.REDIS_URL}}` | Queue, cache and session store |
| `PORT` | `8080` | Port Apache listens on |

Optional, not set by the template:

- `MAIL_MAILER`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_ENCRYPTION`, `MAIL_FROM_ADDRESS`: the app's own system mail (password resets and user invitations). Defaults to `log`, so those emails only go to the logs until you set an SMTP server. Campaign emails don't use these: they go through the email service you add in the app.
- `SENDPORTAL_REGISTER=true` to open public sign-up, `SENDPORTAL_PASSWORD_RESET=false` to turn off password resets.

## After deploying

1. Open the public URL and log in with `SENDPORTAL_ADMIN_EMAIL` and `SENDPORTAL_ADMIN_PASSWORD`.
2. Add an email service under **Email Services** (SES, SendGrid, Mailgun, Postmark, Mailjet, Postal or SMTP). For SMTP, enter `tls` in the Encryption field: SendPortal 4.0 builds an invalid mail transport when it's empty.
3. Point your provider's webhooks at `https://YOUR-DOMAIN/api/v1/webhooks/<provider>` (for example `.../webhooks/postmark`) to record deliveries, bounces and complaints.
4. Add subscribers (form, CSV import or the API under **API Keys**), then create and send a campaign.

Horizon's dashboard is at `/horizon` (workspace owners only).

## Updates

Railway tells everyone who deployed this template when a change lands on this repo's `main` branch, and they choose when to apply it. Each version is listed in [`CHANGELOG.md`](CHANGELOG.md), breaking changes first. Migrations run on start, so an update applies database changes by itself. Back up the Postgres volume before a major version.

## Local test

```sh
docker build -t sendportal-railway .
```

Then run it with a Postgres and a Redis, and the variables above (`DATABASE_URL`, `REDIS_URL`, `APP_KEY` of 32 characters, `APP_URL`, `SENDPORTAL_ADMIN_EMAIL`, `SENDPORTAL_ADMIN_PASSWORD`).

## License

SendPortal is MIT licensed, by Mettle.
