<!-- Installed as ~/.claude/CLAUDE.md by modules/features/ai.nix in mikos-den. Edit dots/claude/CLAUDE.md there. -->

# Personal instructions

These apply in every project.

## Version control

- My repositories use Jujutsu (`jj`) on top of git. In a repository with a `.jj` folder, use `jj`,
  and do not run git commands that change state, such as commit, switch, rebase, merge or stash.
  Git commands that only read are fine.
- A change's description is its commit message. Set it with `jj describe -m`.

## Commits

- Write commit messages as Conventional Commits, on one line. Add a body only when the change is
  really complex.
- Keep the subject short, under about 60 characters. Say what the change does, not how or why:
  leave the mechanism, the details and the reasons to the diff. Write
  `feat(plannotator): add plannotator for plan and code review`, not
  `feat(plannotator): review plans and diffs from Claude Code in Plannotator, pinned with its plugin and with the usage ping off`.
- Never add a `Co-authored-by` trailer.

## Code comments

- Write a comment only when it tells a competent reader something the code cannot: why a
  non-obvious choice was made, a constraint that lives outside the file, or a trap.
- Do not write comments that restate what the code does, explain what a file, option or
  well-known tool is, or label sections.
- Do not comment an option whose meaning is in its documentation, or a pattern the repo already
  uses elsewhere.
- When unsure, leave the comment out.
