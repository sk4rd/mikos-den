# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

NixOS configuration for `workstation`, `thinkpad-z13` and `nas`: a dendritic flake on den, with hjem
for user files and agenix for secrets. Read `docs/architecture.md` before restructuring anything.

## Checking work

There are no tests. A change is done when the affected hosts evaluate and the formatting check passes.

- `nix fmt`: formats everything (nixfmt, stylua, shfmt, ruff, taplo). Run it after editing.
- `nix flake check`: the formatting, statix and deadnix checks plus evaluation of every host.
  Nothing runs them automatically, so run this before you call a change done.
- One host: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- One option: `nix eval .#nixosConfigurations.<host>.config.<option.path>`
- In a VM: `nixos-rebuild build-vm --flake .#<host> && ./result/bin/run-<host>-vm` (login password `test`)

## Gotchas

- Every `.nix` file under `modules/` is loaded automatically, but a flake only sees files git knows
  about. Any `jj` command registers new files with git, so run `jj st` after creating a file and
  before evaluating.
- An aspect every host needs adds itself with `den.schema.host.includes` in its own file. Don't
  add it to a host's include list.
- `config.theme` is the flake-level config. Read it from a file's top-level arguments, not from inside
  the `nixos` or `hjem` modules. Hex colours belong only in `lib/theme/oxocarbon.nix`.
- A new NAS service declares its routes, health checks and datasets as quirks, following
  `jellyfin.nix`, and goes in the include list in `modules/hosts/nas.nix`. Its routes are private
  unless it sets `public = true`.
- After a palette change, run `nix eval --raw .#banner > docs/banner.svg`. GitHub only shows the
  committed file.
- `REVIEW.md` is a review from 2026-11-09. Check a finding against the current code before acting on it.

## Version control

This repository uses Jujutsu (`jj`) on top of git. Use `jj` commands, and do not run git commands
that change state.
A checkout without a `.jj` folder, such as a fresh clone or a cloud session, is plain
git: run `jj git init` there first, or use git if `jj` is not installed.

- One task per workspace. `claude -w <name>` creates one with `jj workspace add`, starting from
  `main`. Never create a folder with `git worktree add`: `jj` run inside it acts on the main checkout.
- Your work is the workspace's working-copy change. Finish by running the checks and naming the
  change with `jj describe -m "<message>"`. Do not move the `main` bookmark and do not push. The
  user reviews the change first and moves `main` themselves.
- When reworking after a review, keep editing the same change. Do not start a second one.
- Descriptions follow Conventional Commits, on one line, without a `Co-authored-by` trailer.

## Left to the user

- Accepting a reviewed change into `main`, and pushing.
- Deploying: the user runs `sudo nixos-rebuild switch --flake .#<host>`.
- Secrets need a YubiKey. Add the recipients to `secrets/agenix-rules.nix`, then the user runs
  `cd secrets && agenix -e <name>.age`. See `docs/secrets.md`.
