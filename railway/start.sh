#!/bin/sh
# SendPortal start script for Railway: web (Apache + PHP), Horizon queue
# workers and the Laravel scheduler in one container, under supervisord.
set -eu
cd /var/www/html

# Fixed settings with sensible defaults (any of them can be overridden by a variable).
export PORT="${PORT:-8080}"
export APP_NAME="${APP_NAME:-SendPortal}"
export APP_ENV="${APP_ENV:-production}"
export APP_DEBUG="${APP_DEBUG:-false}"
export LOG_CHANNEL="${LOG_CHANNEL:-stderr}"
export DB_CONNECTION="${DB_CONNECTION:-pgsql}"
export QUEUE_CONNECTION="${QUEUE_CONNECTION:-redis}"
export CACHE_DRIVER="${CACHE_DRIVER:-redis}"
export SESSION_DRIVER="${SESSION_DRIVER:-redis}"
export SESSION_SECURE_COOKIE="${SESSION_SECURE_COOKIE:-true}"
export MAIL_MAILER="${MAIL_MAILER:-log}"
export SENDPORTAL_REGISTER="${SENDPORTAL_REGISTER:-false}"
export SENDPORTAL_PASSWORD_RESET="${SENDPORTAL_PASSWORD_RESET:-true}"
if [ -z "${APP_URL:-}" ] && [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ]; then
  export APP_URL="https://${RAILWAY_PUBLIC_DOMAIN}"
fi
case "${APP_URL:-}" in http://localhost*|"") export SESSION_SECURE_COOKIE="${SESSION_SECURE_COOKIE_LOCAL:-false}";; esac
if [ -z "${MAIL_FROM_ADDRESS:-}" ]; then
  host="$(echo "${APP_URL:-http://localhost}" | sed -E 's#^[a-z]+://##; s#[:/].*$##')"
  export MAIL_FROM_ADDRESS="sendportal@${host}"
fi

if [ -z "${APP_KEY:-}" ]; then
  echo "APP_KEY is not set: set it to a 32-character random string." >&2
  exit 1
fi

# Laravel's caches must be rebuilt from this container's variables.
su -s /bin/sh www-data -c 'php artisan optimize:clear' >/dev/null

echo "Waiting for the database and running migrations..."
i=0
until su -s /bin/sh www-data -c 'php artisan migrate --force --no-interaction'; do
  i=$((i + 1))
  if [ "$i" -ge 30 ]; then
    echo "Migrations failed after 30 attempts." >&2
    exit 1
  fi
  sleep 3
done

su -s /bin/sh www-data -c 'php /opt/sendportal/create-admin.php'
su -s /bin/sh www-data -c 'php artisan config:cache && php artisan route:cache && php artisan view:cache' >/dev/null
# Horizon restarts its workers cleanly on a new deploy.
su -s /bin/sh www-data -c 'php artisan horizon:terminate' >/dev/null 2>&1 || true

exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
