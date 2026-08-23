#!/usr/bin/env bash
# Point a hostname at this network's current public IPv4 via Namecheap Dynamic DNS.
#
# Setup (once, in Namecheap -> domain -> Advanced DNS):
#   1. Add an A record for $HOST with any placeholder value, TTL 1 min.
#      Namecheap UPDATES an existing record; it will not create one.
#   2. Toggle Dynamic DNS on and copy the generated password.
#   3. umask 077; printf %s '<password>' > ~/.config/namecheap-ddns.pass
#
# Then run it from a timer (systemd --user, or cron) every 5 minutes.
set -euo pipefail

HOST=${DDNS_HOST:-mc}
DOMAIN=${DDNS_DOMAIN:-odio.dev}
PASSFILE=${DDNS_PASSFILE:-$HOME/.config/namecheap-ddns.pass}

[[ -r $PASSFILE ]] || { echo "FATAL: $PASSFILE missing or unreadable" >&2; exit 1; }
PASSWORD=$(<"$PASSFILE")
[[ -n $PASSWORD ]] || { echo "FATAL: $PASSFILE is empty" >&2; exit 1; }

IP=$(curl -4fsS --max-time 15 https://api.ipify.org)
[[ $IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "FATAL: bad public IP: $IP" >&2; exit 1; }

# Parameters go in over stdin, not argv: anything on the command line is
# readable by any local user via `ps` / /proc/<pid>/cmdline, and this runs on a
# timer every few minutes.
RESP=$(curl -fsS --max-time 20 --get --config - <<CFG
url = "https://dynamicdns.park-your-domain.com/update"
data-urlencode = "host=$HOST"
data-urlencode = "domain=$DOMAIN"
data-urlencode = "password=$PASSWORD"
data-urlencode = "ip=$IP"
CFG
)

ERRS=$(grep -oE "<ErrCount>[0-9]+</ErrCount>" <<<"$RESP" | grep -oE "[0-9]+" || echo "?")
if [[ $ERRS != 0 ]]; then
  # Never print $RESP verbatim -- Namecheap echoes the password back inside it.
  echo "FATAL: Namecheap rejected the update (ErrCount=$ERRS)" >&2
  grep -oE "<Err[0-9]+>[^<]*</Err[0-9]+>" <<<"$RESP" >&2 || true
  exit 1
fi
echo "$HOST.$DOMAIN -> $IP (ok)"
