#!/bin/bash
# Railway boot for Discourse.
#
# Refuses to start without strong secrets and the database and Redis settings, takes the public host from Railway's domain,
# points nginx at the injected PORT, makes the /shared volume writable for upstream's uid, and, once the app answers, creates
# the administrator, its API key and a closed sign-up (bootstrap.rb). Then hands over to upstream's boot.
set -u
fail() { echo "[railway] $1" >&2; exit 1; }
ADMIN_API_KEY="${ADMIN_API_KEY:-}"
[ -n "${ADMIN_PASSWORD:-}" ] || fail "ADMIN_PASSWORD is not set; refusing to start a forum with no admin login"
[ "${#ADMIN_PASSWORD}" -ge 12 ] || fail "ADMIN_PASSWORD must be at least 12 characters"
[ -n "${ADMIN_EMAIL:-}" ] || fail "ADMIN_EMAIL is not set"
[ "${#ADMIN_API_KEY}" -ge 32 ] || fail "ADMIN_API_KEY must be set and at least 32 characters"
for v in DB_HOST DB_USERNAME DB_PASSWORD DB_NAME REDIS_HOST REDIS_PASSWORD; do
  eval "val=\${DISCOURSE_$v:-}"
  [ -n "$val" ] || fail "DISCOURSE_$v is not set"
done
case "${PORT:=8080}" in ''|*[!0-9]*) fail "PORT must be a number, got '$PORT'";; esac
if [ -z "${DISCOURSE_HOSTNAME:-}" ]; then
  [ -n "${RAILWAY_PUBLIC_DOMAIN:-}" ] || fail "neither DISCOURSE_HOSTNAME nor RAILWAY_PUBLIC_DOMAIN is set"
  export DISCOURSE_HOSTNAME="$RAILWAY_PUBLIC_DOMAIN"
fi
export PORT

echo "[railway] Discourse on :$PORT as $DISCOURSE_HOSTNAME, postgres $DISCOURSE_DB_HOST, redis $DISCOURSE_REDIS_HOST, /shared owner before=$(stat -c %u:%g /shared)"

# nginx listens on 80 upstream; Railway's healthcheck and edge dial the injected PORT
sed -i "s/^listen 80;/listen $PORT;/; s/^listen \[::\]:80;/listen [::]:$PORT;/" /etc/nginx/conf.d/outlets/server/10-http.conf
rm -f /etc/nginx/sites-enabled/default

# a volume mounted at /shared hides what the image created there
mkdir -p /shared/uploads /shared/backups /shared/tmp /shared/log/rails
chown -R discourse:www-data /shared/uploads /shared/backups /shared/tmp /shared/log/rails || fail "could not hand /shared to discourse"
echo "[railway] /shared owner after=$(stat -c %u:%g /shared/uploads)"

(
  n=0
  until curl -fsS -o /dev/null "http://127.0.0.1:$PORT/srv/status" 2>/dev/null; do
    n=$((n + 1)); [ "$n" -le 600 ] || { echo "[railway] app never came up, admin not created" >&2; exit 1; }
    sleep 3
  done
  for try in 1 2 3 4 5; do
    if su discourse -c 'cd /var/www/discourse && RAILS_ENV=production bundle exec rails runner /railway-bootstrap.rb' 2>&1; then exit 0; fi
    echo "[railway] bootstrap failed (try $try)" >&2; sleep 10
  done
  echo "[railway] administrator not created" >&2
) &

exec "$@"
