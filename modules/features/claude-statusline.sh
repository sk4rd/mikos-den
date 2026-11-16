# Claude Code gives the subscription limits only to the status line command, so this saves them for
# the Noctalia widget (dots/noctalia/claude/usage.luau). It then runs the status line that
# ~/.claude/settings.json names, because the managed setting that starts this script hides it.
input=$(cat)

cache=${XDG_CACHE_HOME:-$HOME/.cache}/claude-rate-limits.json

# rate_limits is missing until the first answer of a session. Nothing is written then,
# so the widget keeps the last known numbers.
limits=$(jq -c 'select(.rate_limits | length > 0) | {updated_at: now | floor, rate_limits}' <<<"$input" 2>/dev/null)
if [ -n "$limits" ]; then
  mkdir -p "${cache%/*}"
  tmp=$(mktemp "$cache.XXXXXX") && printf '%s\n' "$limits" >"$tmp" && mv "$tmp" "$cache"
fi

own=$(jq -r '.statusLine.command // empty' "$HOME/.claude/settings.json" 2>/dev/null)
if [ -n "$own" ]; then
  printf '%s' "$input" | sh -c "$own"
fi
