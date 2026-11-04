set -u

status_dir="/run/media-vpn-health"
mkdir -p "$status_dir"

ok=true
errors=()

fail() {
  ok=false
  errors+=("$1")
}

handshake_age=999999
rx_bytes=0
egress=""
host_egress=""
dns_ok=false
nscd_hidden=false
qbittorrent_ok=false
zfs_capacity=0

peer=$(ip netns exec media-vpn wg show wg-media dump 2>/dev/null | sed -n '2p')
if [ -n "${peer:-}" ]; then
  handshake=$(printf '%s\n' "$peer" | awk '{ print $5 }')
  rx_bytes=$(printf '%s\n' "$peer" | awk '{ print $6 }')
  if [ -n "${handshake:-}" ]; then
    handshake_age=$(($(date +%s) - handshake))
  else
    fail "wireguard handshake unavailable"
  fi
else
  fail "wireguard peer unavailable"
fi

if [ "$handshake_age" -ge 180 ]; then
  fail "wireguard handshake is ${handshake_age}s old"
fi
if [ "$rx_bytes" -le 0 ]; then
  fail "wireguard has received no bytes"
fi

if egress=$(ip netns exec media-vpn curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null); then
  :
else
  egress=""
  fail "namespace egress check failed"
fi
host_egress=$(curl -4 -fsS --max-time 5 https://api.ipify.org 2>/dev/null || true)
if [ -n "$egress" ] && [ "$egress" = "$host_egress" ]; then
  fail "namespace egress equals the host WAN address"
fi

pid=$(systemctl show qbittorrent -p MainPID --value 2>/dev/null || true)
if [ -n "${pid:-}" ] && [ "$pid" != "0" ] && systemctl is-active --quiet qbittorrent; then
  qbittorrent_ok=true
else
  fail "qbittorrent is not active"
fi

if [ -n "${pid:-}" ] && [ "$pid" != "0" ]; then
  if nsenter -t "$pid" -m -n -- getent ahostsv4 example.com >/dev/null 2>&1; then
    dns_ok=true
  else
    fail "DNS resolution inside qbittorrent failed"
  fi
  if nsenter -t "$pid" -m -n -- test ! -S /run/nscd/socket; then
    nscd_hidden=true
  else
    fail "nscd socket is visible inside qbittorrent"
  fi
  if nsenter -t "$pid" -n -- ss -H -tln 2>/dev/null | grep -q '10\.2\.0\.2%wg-media'; then
    :
  else
    fail "qbittorrent is not listening on wg-media"
  fi
fi

if capacity=$(zpool list -H -o capacity tank 2>/dev/null); then
  zfs_capacity=${capacity%\%}
else
  fail "zpool capacity unavailable"
fi
if [ "${zfs_capacity:-0}" -ge 85 ]; then
  fail "zfs pool is ${zfs_capacity}% full"
fi

error_message=$(
  IFS='; '
  echo "${errors[*]:-}"
)

jq -n \
  --argjson ok "$ok" \
  --argjson handshake_age "$handshake_age" \
  --argjson rx_bytes "$rx_bytes" \
  --arg egress "$egress" \
  --arg host_egress "$host_egress" \
  --argjson dns "$dns_ok" \
  --argjson nscd_hidden "$nscd_hidden" \
  --argjson qbittorrent "$qbittorrent_ok" \
  --argjson zfs_capacity "$zfs_capacity" \
  --arg error "$error_message" \
  --arg checked_at "$(date -Iseconds)" \
  '{
    ok: $ok,
    handshake_age: $handshake_age,
    rx_bytes: $rx_bytes,
    egress: $egress,
    host_egress: $host_egress,
    dns: $dns,
    nscd_hidden: $nscd_hidden,
    qbittorrent: $qbittorrent,
    zfs_capacity: $zfs_capacity,
    error: $error,
    checked_at: $checked_at
  }' >"$status_dir/status.json"

chmod 0644 "$status_dir/status.json"
