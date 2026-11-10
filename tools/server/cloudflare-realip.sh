#!/bin/sh
# DISABLED (10 Nov 2026). Running it took ayattla.com down: every visitor got nginx's
# "403 Forbidden" until the backup was restored. The site's nginx config evidently allows only
# certain addresses (most likely Cloudflare's ranges); while nginx saw every visitor as a
# Cloudflare address they passed, and once it saw their real address they were refused. The
# script's own check passed because it asked the site from the server, whose address is allowed.
# Do not re-enable before reading the site's allow/deny rules (CloudPanel vhost) and changing
# them together with real_ip in one step, verified from OUTSIDE the server. See CONTINUE.md.
echo "!! This script is disabled: it blocked every visitor on 10 Nov 2026. Nothing was changed."
exit 1

# --- original script kept below for reference; never reached ---
# Lets nginx see each visitor's real address behind Cloudflare, safely.
#
# Found 10 Nov 2026: nginx.conf trusts every address (set_real_ip_from 0.0.0.0/0) with no
# real_ip_header, so nginx reads X-Real-IP, which Cloudflare does not send: the logs show
# Cloudflare's addresses, and anyone reaching the server directly could fake their address.
#
# What it does:
#   1. backs up nginx.conf to ~/backups/nginx-realip-<time>/
#   2. downloads Cloudflare's published ranges and checks them
#   3. replaces the 0.0.0.0/0 line with an include of /etc/nginx/cloudflare-realip.conf
#      (Cloudflare's ranges + real_ip_header CF-Connecting-IP); the private ranges stay
#   4. runs nginx -t; reloads only if it passes; checks the site answers through Cloudflare
#   5. on any failure, puts the backup back and reloads, so the site stays as it was
# Running it again only refreshes the ranges.
#   curl -fsSL https://raw.githubusercontent.com/ayattla/ayattla-ios/main/tools/server/cloudflare-realip.sh | sh
set -u
CONF="${CONF:-/etc/nginx/nginx.conf}"
INC="${INC:-/etc/nginx/cloudflare-realip.conf}"
BKROOT="${BKROOT:-$HOME/backups}"
SITE="${SITE:-https://ayattla.com/}"
fetch() { curl -fsS --max-time 20 "$1"; }

[ "$(id -u)" = 0 ] || [ -n "${ALLOW_NONROOT:-}" ] || { echo "!! run as root"; exit 1; }
[ -f "$CONF" ] || { echo "!! $CONF not found"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S)
BK="$BKROOT/nginx-realip-$ts"
mkdir -p "$BK" && cp -p "$CONF" "$BK/nginx.conf" || { echo "!! backup failed, nothing changed"; exit 1; }
had_inc=0; [ -f "$INC" ] && { cp -p "$INC" "$BK/cloudflare-realip.conf"; had_inc=1; }
echo "== backup: $BK"

v4=$(fetch https://www.cloudflare.com/ips-v4) || v4=""
v6=$(fetch https://www.cloudflare.com/ips-v6) || v6=""
c4=$(printf '%s\n' "$v4" | grep -cE '^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$')
c6=$(printf '%s\n' "$v6" | grep -cE '^[0-9a-fA-F:]+/[0-9]{1,3}$')
bad=$(printf '%s\n%s\n' "$v4" "$v6" | grep -v '^$' | grep -vcE '^[0-9]{1,3}(\.[0-9]{1,3}){3}/[0-9]{1,2}$|^[0-9a-fA-F:]+/[0-9]{1,3}$')
if [ "$c4" -lt 10 ] || [ "$c6" -lt 3 ] || [ "$bad" -ne 0 ]; then
  echo "!! Cloudflare's list looks wrong (v4=$c4 v6=$c6 bad=$bad); nothing changed"; exit 1
fi

restore() {
  echo "!! $1 — restoring the backup"
  cp -p "$BK/nginx.conf" "$CONF"
  if [ "$had_inc" = 1 ]; then cp -p "$BK/cloudflare-realip.conf" "$INC"; else rm -f "$INC"; fi
  nginx -t >/dev/null 2>&1 && { systemctl reload nginx 2>/dev/null || nginx -s reload; }
  echo "== restored; the site is as it was"; exit 1
}

{
  echo "# Cloudflare ranges, fetched $(date -u +%Y-%m-%dT%H:%MZ) by tools/server/cloudflare-realip.sh"
  printf '%s\n%s\n' "$v4" "$v6" | grep -v '^$' | sed 's/^/set_real_ip_from /; s/$/;/'
  echo "real_ip_header CF-Connecting-IP;"
} > "$INC.tmp" && mv "$INC.tmp" "$INC"

if grep -q "include $INC;" "$CONF"; then
  echo "== include already present; ranges refreshed"
elif grep -qE '^[[:space:]]*set_real_ip_from[[:space:]]+0\.0\.0\.0/0;' "$CONF"; then
  sed -i -E "s#^([[:space:]]*)set_real_ip_from[[:space:]]+0\.0\.0\.0/0;.*#\1include $INC; \# replaced: set_real_ip_from 0.0.0.0/0 ($ts)#" "$CONF"
else
  restore "the line set_real_ip_from 0.0.0.0/0 was not found (config differs from 10 Nov)"
fi
if [ "$(grep -cE '^[[:space:]]*real_ip_header' "$CONF")" -ne 0 ]; then
  restore "nginx.conf already has its own real_ip_header"
fi

nginx -t >/dev/null 2>&1 || { nginx -t; restore "nginx -t failed"; }
systemctl reload nginx 2>/dev/null || nginx -s reload || restore "reload failed"
sleep 2
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$SITE" || echo 000)
case "$code" in 2??|3??) ;; *) restore "the site answered $code after the change";; esac

echo "== done: site $code; nginx now reads the visitor's address from CF-Connecting-IP"
echo "== Cloudflare ranges: $c4 IPv4, $c6 IPv6. To undo: cp $BK/nginx.conf $CONF && nginx -t && systemctl reload nginx"
