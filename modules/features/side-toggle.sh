# side-toggle <app-id> [command...]
#
# Shows or hides one window of the "side" scratchpad, leaving the others as they are, and opens it in Ghostty first
# when it is missing.
set -euo pipefail

app_id=$1
shift

find_window() {
  umbriel windows --json | jq -r --arg app "$app_id" \
    'map(select(.app_id == $app and .scratchpad == "side")) | first | .id // empty'
}

id=$(find_window)
if [ -z "$id" ]; then
  terminal=(ghostty --class="$app_id" --working-directory=home)
  [ $# -gt 0 ] && terminal+=(-e "$@")
  # Without the token the new window would be activated, and activating a hidden scratchpad window shows every
  # window of the pad.
  env -u XDG_ACTIVATION_TOKEN -u DESKTOP_STARTUP_ID setsid "${terminal[@]}" >/dev/null 2>&1 &
  for _ in $(seq 100); do
    sleep 0.1
    id=$(find_window)
    [ -n "$id" ] && break
  done
  [ -n "$id" ] || exit 1
fi

exec umbriel msg scratchpad-window-toggle "$id"
