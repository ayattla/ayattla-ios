#!/bin/sh
# v2 (10 Nov 2026): the visitor's real address AND the Cloudflare-only lock, changed together.
#
# Why v1 broke the site: ayattla.com.conf lets in only Cloudflare's addresses (allow ... deny all).
# nginx checks allow/deny against the address AFTER real-IP, so once that became the visitor's
# address, every visitor was refused. v2 keeps the same lock but checks the connection itself
# ($realip_remote_addr), so real-IP no longer affects who gets in.
#
#   1. backs up nginx.conf and the site's vhost to ~/backups/nginx-realip2-<time>/ (+ undo.sh)
#   2. reads the existing allow list from the vhost (no list is downloaded)
#   3. writes sites-enabled/00-ayt-realip.conf: set_real_ip_from (that list), real_ip_header
#      CF-Connecting-IP, and geo $realip_remote_addr -> $ayt_origin_ok
#   4. replaces the allow/deny block with a gate on $ayt_origin_ok (/.well-known stays open, as before)
#   5. comments out "set_real_ip_from 0.0.0.0/0" in nginx.conf
#   6. nginx -t, otherwise restores and stops
#   7. reloads, and arms an automatic undo after $GRACE seconds unless $BK/keep exists:
#      the site must be checked from OUTSIDE the server before keeping it.
set -u
CONF="${CONF:-/etc/nginx/nginx.conf}"
VHOST="${VHOST:-/etc/nginx/sites-enabled/ayattla.com.conf}"
INC="${INC:-/etc/nginx/sites-enabled/00-ayt-realip.conf}"
BKROOT="${BKROOT:-$HOME/backups}"
GRACE="${GRACE:-180}"
reload() { systemctl reload nginx 2>/dev/null || nginx -s reload; }

[ "$(id -u)" = 0 ] || [ -n "${ALLOW_NONROOT:-}" ] || { echo "!! run as root"; exit 1; }
[ -f "$CONF" ] && [ -f "$VHOST" ] || { echo "!! config files not found; nothing changed"; exit 1; }
[ -e "$INC" ] && { echo "!! $INC already exists; nothing changed"; exit 1; }

ts=$(date +%Y%m%d-%H%M%S); BK="$BKROOT/nginx-realip2-$ts"
mkdir -p "$BK" && cp -p "$CONF" "$BK/nginx.conf" && cp -p "$VHOST" "$BK/vhost.conf" || { echo "!! backup failed; nothing changed"; exit 1; }
cat > "$BK/undo.sh" <<UNDO
#!/bin/sh
cp -p "$BK/nginx.conf" "$CONF"; cp -p "$BK/vhost.conf" "$VHOST"; rm -f "$INC"
nginx -t >/dev/null 2>&1 && { systemctl reload nginx 2>/dev/null || nginx -s reload; }
touch "$BK/keep"; echo "== undone: nginx is as it was before $ts"
UNDO
echo "== backup: $BK"

# The allow block: the first "allow 173.245.48.0/20;" through the next "deny all;", allow lines only.
start=$(grep -nE '^[[:space:]]*allow[[:space:]]+173\.245\.48\.0/20;[[:space:]]*$' "$VHOST" | head -1 | cut -d: -f1)
[ -n "$start" ] || { echo "!! allow block not found; nothing changed"; exit 1; }
end=$(awk -v s="$start" 'NR>=s && /^[[:space:]]*deny[[:space:]]+all;[[:space:]]*$/ {print NR; exit}' "$VHOST")
[ -n "$end" ] || { echo "!! deny all not found after the allow block; nothing changed"; exit 1; }
block=$(sed -n "${start},$((end-1))p" "$VHOST")
bad=$(printf '%s\n' "$block" | grep -vcE '^[[:space:]]*allow[[:space:]]+[0-9a-fA-F:./]+;[[:space:]]*$')
addrs=$(printf '%s\n' "$block" | sed -E 's/^[[:space:]]*allow[[:space:]]+([^;]+);.*/\1/')
n=$(printf '%s\n' "$addrs" | grep -c .)
if [ "$bad" -ne 0 ] || [ "$n" -lt 20 ] || ! printf '%s\n' "$addrs" | grep -qx '127.0.0.1'; then
  echo "!! allow block looks different from 10 Nov (lines $start-$end, $n addresses, $bad other lines); nothing changed"; exit 1
fi
[ "$(grep -cE '^[[:space:]]*set_real_ip_from[[:space:]]+0\.0\.0\.0/0;' "$CONF")" = 1 ] || { echo "!! set_real_ip_from 0.0.0.0/0 not found once in nginx.conf; nothing changed"; exit 1; }
grep -qE '^[[:space:]]*real_ip_header' "$CONF" "$VHOST" && { echo "!! a real_ip_header already exists; nothing changed"; exit 1; }

restore() {
  echo "!! $1 — restoring the backup"
  cp -p "$BK/nginx.conf" "$CONF"; cp -p "$BK/vhost.conf" "$VHOST"; rm -f "$INC"
  nginx -t >/dev/null 2>&1 && reload
  echo "== restored; nginx is as it was"; exit 1
}

{
  echo "# ayattla.com behind Cloudflare — tools/server/cloudflare-realip-v2.sh ($ts)"
  echo "# Visitor address from CF-Connecting-IP, trusted only on connections from these addresses."
  printf '%s\n' "$addrs" | grep -vxE '127\.0\.0\.1' | sed 's/^/set_real_ip_from /; s/$/;/'
  echo "real_ip_header CF-Connecting-IP;"
  echo "# The Cloudflare-only gate checks the connection itself, not the visitor address."
  echo 'geo $realip_remote_addr $ayt_origin_ok {'
  echo "    default 0;"
  printf '%s\n' "$addrs" | sed 's/^/    /; s/$/ 1;/'
  echo "}"
} > "$INC"

gate_file="$BK/gate.txt"
cat > "$gate_file" <<'GATE'
    # Cloudflare-only gate on the connecting address (was allow/deny; see 00-ayt-realip.conf)
    set $ayt_gate $ayt_origin_ok;
    if ($uri ~ "^/\.well-known/") { set $ayt_gate 1; }
    if ($ayt_gate = 0) { return 403; }
GATE
awk -v s="$start" -v e="$end" -v g="$gate_file" 'NR==s{while((getline l < g)>0) print l} NR>=s && NR<=e {next} {print}' "$BK/vhost.conf" > "$VHOST.tmp" && cat "$VHOST.tmp" > "$VHOST" && rm -f "$VHOST.tmp"
sed -i -E "s#^([[:space:]]*)set_real_ip_from[[:space:]]+0\.0\.0\.0/0;#\1\# set_real_ip_from 0.0.0.0/0;  (off since $ts: Cloudflare list in 00-ayt-realip.conf)#" "$CONF"

nginx -t >/dev/null 2>&1 || { nginx -t; restore "nginx -t failed"; }

# Automatic undo unless someone confirms from outside the server within $GRACE seconds.
setsid sh -c "sleep $GRACE; [ -f '$BK/keep' ] || { sh '$BK/undo.sh' > '$BK/auto-undo.log' 2>&1; }" >/dev/null 2>&1 < /dev/null &
reload || restore "reload failed"
echo "== applied: $n addresses; nginx reads the visitor from CF-Connecting-IP; the gate checks the connection"
echo "== CHECK THE SITE FROM OUTSIDE NOW. It undoes itself in $GRACE s unless you run:  touch $BK/keep"
echo "== undo now:  sh $BK/undo.sh"
