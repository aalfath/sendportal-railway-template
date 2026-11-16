# Changelog

## 4.0.0.1-r2 (2026-11-16)

- README: Deploy on Railway button for the published template (`sendportal-1`). No change to the app or the image.

## 4.0.0.1-r1 (2026-11-16)

First release of the Railway template.

- SendPortal v4.0.0.1 (Laravel 13, sendportal-core v4.0.1) on `php:8.4.27-apache-trixie`, pinned by digest, with phpredis 6.3.0.
- One service runs Apache + PHP, Horizon and the scheduler under supervisord; Railway Postgres and Redis.
- The first admin and workspace are created from `SENDPORTAL_ADMIN_EMAIL` and `SENDPORTAL_ADMIN_PASSWORD`, so the `/setup` wizard is never open to visitors.
- Migrations run on every start.
- If Apache, Horizon or the scheduler stops for good, the container exits so Railway restarts it; only the prefork MPM is kept enabled.
