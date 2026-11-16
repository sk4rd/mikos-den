function review --description 'Review a branch in its worktree' --argument-names branch
  if test -z "$branch"
    inbox
    return
  end

  if not git show-ref --verify --quiet refs/heads/$branch
    echo "review: no branch named $branch" >&2
    return 1
  end

  set -l path (git for-each-ref --format='%(worktreepath)' refs/heads/$branch)
  if test -z "$path"
    echo "review: $branch has no worktree. Create one: git worktree add .claude/worktrees/$branch $branch" >&2
    return 1
  end

  set -l base (git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | string replace origin/ '')
  test -n "$base"; or set base main

  cd $path; and nvim -c "DiffviewOpen $base...HEAD --imply-local"
end
