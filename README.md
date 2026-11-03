# mikos-den

Switch to the config using flakes:

```sh
sudo nixos-rebuild switch --flake .#<host>
```

## Explore aspects

Generate a static overview of the repository's aspects and their relationships:

```sh
nix eval --raw .#diagrams.overview > /tmp/mikos-den-overview.mmd
```

The overview includes authored `includes` and schema-level root relationships.

## Formatting

Format the whole repository (Nix, Lua, shell, Python, TOML) with
[treefmt-nix](https://github.com/numtide/treefmt-nix), configured in
`modules/formatter.nix`:

```sh
nix fmt
```

`nix flake check` fails if any file is not formatted.

## Install from a NixOS live ISO

Partition disk using disko:
```sh
sudo nix --extra-experimental-features "nix-command flakes" run \
  github:nix-community/disko -- \
  --mode destroy,format,mount --flake .#<host-using-disko>
```

Before installing, place your host's age key at `/mnt/etc/age/host.key`.
```sh
sudo install -d -m 0700 /mnt/etc/age
sudo install -m 0600 /path/to/host.key /mnt/etc/age/host.key
```

The key decrypts the agenix secrets at boot, so back it up separately. Then
install:
```sh
sudo nixos-install --flake .#<host>
```

## Secrets

Before adding a secret make sure to declare its recipients in
=agenix-rules.nix=.

Adding and editing a secret:
```sh
cd secrets
agenix -e very-secret-secret.age -i ~/.config/age/keys.txt  # opens $EDITOR
```

The identities are the YubiKey age plugin keys (PIV slot 2), provisioned by
`modules/features/yubikey.nix` as `~/.config/age/keys-<serial>.txt` on every
host, one per YubiKey. `agenix` only auto-detects `~/.ssh/id_*`, so the fish
wrapper passes the file matching the connected YubiKey; give `-i` yourself to
override it. Without the wrapper, `~/.config/age/keys.txt` holds both
identities — but `age-plugin-yubikey` will then ask for the YubiKey you are
not using, on every decryption.

## Test VM

Every host includes the `nixos-testing-vm` aspect, which sets up
`virtualisation.vmVariant`. Build and run it with:
```sh
nixos-rebuild build-vm --flake .#<host>
./result/bin/run-<host>-vm
```

## Notes vault and backup

Obsidian vault `~/Notes` on the workstation and thinkpad, synced by Syncthing
through the NAS (`/tank/data/documents/notes`, covered by ZFS snapshots). Every
night the NAS backs the vault up with restic to `/tank/backups/restic` and copies
that repository to Proton Drive (`/my-files/Backups/nas`). Gatus on the NAS
alerts via ntfy when a backup, upload or the weekly integrity check fails or
doesn't run (group **Backups**).

The restic password is in `secrets/restic-password.age`; keep a copy in your
password manager, since the backups can't be restored without it.

Restore from Proton Drive: download `/my-files/Backups/nas` to a folder, then
```sh
restic -r <folder> unlock   # if it complains about a lock
restic -r <folder> snapshots
restic -r <folder> restore latest --target <dest>
```
On the NAS the local copy is restored with `sudo restic -r /tank/backups/restic
--password-file /run/agenix/restic-password restore latest --target <dest>`.

If the Proton sign-in expires, run `sudo proton-backup-login` on the NAS again.

An old Logseq database from the vault folder was moved to
`/tank/data/documents/logseq-notes-old` (2026-11-03); delete it when sure.
