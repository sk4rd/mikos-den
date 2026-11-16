<!-- Installed as ~/.claude/CLAUDE.md by modules/features/ai.nix in mikos-den. Edit dots/claude/CLAUDE.md there. -->

# Personal instructions

These apply in every project.

## Commits

- Write commit messages as Conventional Commits, on one line. Add a body only when the change is
  really complex.
- Never add a `Co-authored-by` trailer.

## Code comments

- Write a comment only when it tells a competent reader something the code cannot: why a
  non-obvious choice was made, a constraint that lives outside the file, or a trap.
- Do not write comments that restate what the code does, explain what a file, option or
  well-known tool is, or label sections.
- Do not comment an option whose meaning is in its documentation, or a pattern the repo already
  uses elsewhere.
- When unsure, leave the comment out.
