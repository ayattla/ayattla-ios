#!/bin/sh
# Read-only look at the server before any tuning. Changes nothing and prints no secrets:
# only sizes, counts and the names of the nginx directives that matter for load.
#   curl -fsSL https://raw.githubusercontent.com/ayattla/ayattla-ios/main/tools/server/inspect.sh | sh
echo "== CPU and memory"
echo "cores: $(nproc)"
free -m | awk 'NR==1 || /Mem|Swap/'
echo "load: $(cut -d' ' -f1-3 /proc/loadavg)"
echo "== disk"
df -h / | tail -1
echo "== app workers (uvicorn/gunicorn processes)"
ps -eo comm,args | grep -E 'uvicorn|gunicorn' | grep -v grep | grep -oE -- '(uvicorn|gunicorn)|--workers[ =][0-9]+' | sort | uniq -c
echo "== nginx"
nginx -v 2>&1
conf=$(nginx -T 2>/dev/null)
for d in worker_processes worker_connections gzip brotli proxy_cache_path proxy_cache limit_req_zone limit_req keepalive_timeout real_ip_header set_real_ip_from; do
  n=$(printf '%s\n' "$conf" | grep -cE "^[[:space:]]*$d[[:space:]]")
  echo "$d: $n"
done
echo "== nginx locations for the API"
printf '%s\n' "$conf" | grep -E "^[[:space:]]*location[[:space:]]" | sort | uniq -c | head -40
echo "== done (nothing was changed)"
