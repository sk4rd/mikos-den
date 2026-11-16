function inbox --description 'List branches that wait for review'
  set -l base (git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | string replace origin/ '')
  test -n "$base"; or set base main

  git for-each-ref --format='%(refname:short)%09%(worktreepath)' refs/heads | while read -l -d \t branch path
    test "$branch" = "$base"; and continue

    set -l ahead (git rev-list --count $base..$branch)
    set -l dirty 0
    test -n "$path"; and set dirty (git -C $path status --porcelain | count)
    test $ahead -eq 0 -a $dirty -eq 0; and continue

    set -l state ready
    set -l summary (git diff --shortstat $base...$branch | string trim)
    if test $dirty -gt 0
      set state open
      set summary "$dirty uncommitted"
    end

    set -l age -
    test $ahead -gt 0; and set age (git log -1 --format=%cr $branch)

    printf '%s\t%s\t%s\t%s\n' $state $branch $age "$summary"
  end | sort -t \t -k1,1r -k2,2 | column -t -s \t
end
