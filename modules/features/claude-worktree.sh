# A WorktreeCreate hook replaces Claude Code's own git worktree handling in every
# repository, so the plain git case is handled here too.
set -euo pipefail

input=$(cat)

repo_root() {
  local common
  common=$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)
  echo "${common%/.git}"
}

case "$1" in
  create)
    name=$(jq -er .name <<<"$input")
    root=$(repo_root "$(jq -er .cwd <<<"$input")")
    dir="$root/.claude/worktrees/$name"
    if [ -d "$root/.jj" ]; then
      base=main
      jj -R "$root" log --no-graph -r main -T '""' >/dev/null 2>&1 || base='trunk()'
      mkdir -p "$root/.claude/worktrees"
      jj -R "$root" workspace add --name "$name" -r "$base" "$dir" >&2
    else
      git -C "$root" worktree add -b "worktree-$name" "$dir" >&2
    fi
    echo "$dir"
    ;;
  remove)
    dir=$(jq -er .worktree_path <<<"$input")
    root=$(repo_root "$dir")
    if [ -d "$dir/.jj" ]; then
      jj -R "$root" workspace remove "$(basename "$dir")" >&2
    else
      git -C "$root" worktree remove --force "$dir" >&2
      git -C "$root" branch -d "worktree-$(basename "$dir")" >&2 || true
    fi
    ;;
esac
