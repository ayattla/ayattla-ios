#!/bin/sh
# One-time setup on the owner's server (Hostinger VPS web terminal): keeps a private copy of
# ayattla/ayattla-ios that the SERVER pulls from GitHub every day. No secret ever leaves the
# server: its key is generated here, and only the public half is added to GitHub (read only).
#   ~/backups/ayattla-ios-app/ayattla-ios.git                 every branch and the full history
#   ~/backups/ayattla-ios-app/bundles/ayattla-ios-main-DATE.bundle   one-file copy of main (last 30 kept)
# Its own folder, so it never mixes with the site's backups in ~/backups. Safe to run again;
# an earlier setup straight in ~/backups is moved into the new folder.
set -e
command -v git >/dev/null 2>&1 || { (apt-get update -qq && apt-get install -y -qq git) || (dnf install -y -q git); }
command -v ssh-keygen >/dev/null 2>&1 || { (apt-get install -y -qq openssh-client) || (dnf install -y -q openssh-clients); }
APP="$HOME/backups/ayattla-ios-app"
mkdir -p "$APP/bundles" "$HOME/.ssh"
# Move a first-version setup (files straight in ~/backups) into the app's own folder.
[ -d "$HOME/backups/ayattla-ios.git" ] && [ ! -d "$APP/ayattla-ios.git" ] && mv "$HOME/backups/ayattla-ios.git" "$APP/"
for f in "$HOME"/backups/bundles/ayattla-ios-main-*.bundle; do [ -f "$f" ] && mv "$f" "$APP/bundles/"; done
rmdir "$HOME/backups/bundles" 2>/dev/null || true
[ -f "$HOME/backups/backup.log" ] && [ ! -f "$APP/backup.log" ] && mv "$HOME/backups/backup.log" "$APP/"
# The first version's script, only if it is ours.
grep -q 'ayattla-ios.git' "$HOME/backups/backup.sh" 2>/dev/null && rm -f "$HOME/backups/backup.sh"
chmod 700 "$HOME/.ssh"
[ -f "$HOME/.ssh/ayattla_backup" ] || ssh-keygen -t ed25519 -N "" -C "ayattla-backup@server" -f "$HOME/.ssh/ayattla_backup" -q

cat > "$APP/backup.sh" <<'EOS'
#!/bin/sh
# Daily: refresh the mirror (SSH with the read-only deploy key; public HTTPS while the repo is
# public), then write today's one-file copy of main and keep the last 30.
set -e
cd "$HOME/backups/ayattla-ios-app"
export GIT_SSH_COMMAND="ssh -i $HOME/.ssh/ayattla_backup -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
SSH_URL="git@github.com:ayattla/ayattla-ios.git"
HTTPS_URL="https://github.com/ayattla/ayattla-ios.git"
REFS="+refs/heads/*:refs/heads/* +refs/tags/*:refs/tags/*"
if [ ! -d ayattla-ios.git ]; then git init -q --bare ayattla-ios.git; fi
# shellcheck disable=SC2086
git -C ayattla-ios.git fetch -q --prune "$SSH_URL" $REFS 2>/dev/null \
  || git -C ayattla-ios.git fetch -q --prune "$HTTPS_URL" $REFS
d=$(date +%Y-%m-%d)
git -C ayattla-ios.git bundle create "$PWD/bundles/ayattla-ios-main-$d.bundle" main 2>/dev/null
ls -1t bundles/ayattla-ios-main-*.bundle | tail -n +31 | xargs -r rm -f
echo "$(date '+%F %T') ok $(git -C ayattla-ios.git rev-parse --short main)" >> backup.log
EOS
chmod +x "$APP/backup.sh"

# Every day at 03:17 server time.
( crontab -l 2>/dev/null | grep -v -e "$HOME/backups/backup.sh" -e 'ayattla-ios-app/backup.sh' ; echo "17 3 * * * $APP/backup.sh >/dev/null 2>&1" ) | crontab -

"$APP/backup.sh"
echo
echo "== Done. Latest backup:"; tail -1 "$APP/backup.log"; ls -lh "$APP/bundles" | tail -2
du -sh "$APP"
echo
echo "== Public key for GitHub (Settings > Deploy keys > Add deploy key, leave write access OFF):"
cat "$HOME/.ssh/ayattla_backup.pub"
