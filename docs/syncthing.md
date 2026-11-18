# Syncthing

Workstation and laptop sync most of the home directory through the NAS, which stays
online when they don't, and the NAS backs it up to Proton Drive every night. Each host
has a fixed identity committed to this repo, so every device ID is known before the
host first starts. The feature is `modules/features/syncthing.nix`.

Clients dial the hub as `tcp://nas:22000`, never by IP. `nas` is pinned to the NAS's LAN
address (`192.168.178.3`) in `/etc/hosts` on the two client hosts, because the Proton
VPN's exclusive DNS drops the Fritz!Box resolver while it is connected. The address is
reachable at home directly and over the nas tunnel, whose route to `192.168.178.0/24` is
more specific than Proton's default route; at home the direct LAN route wins because
the nas-vpn profile uses `route-metric = 700`, above NetworkManager's LAN defaults. The
pin comes from `lib/network.nix`, the shared source for the home LAN configuration.
With no VPN and away from home, nothing reaches the hub and nothing syncs. The NAS
pins its own name and its peers' names in `/etc/hosts`, because tunnel addresses are
in no DNS zone; a peer reachable by name from the NAS has a `hostname` in
`settings.wireguard-server.peers`.

## Adding a machine

Make it a host in this flake with its age key ([Installing a host](install.md)) that
can reach the NAS by name. Below, `<host>` is its name under `den.hosts.x86_64-linux`.

1. Let it read its key in `secrets/agenix-rules.nix`, using its age public key:

   ```nix
   "syncthing-<host>-key.age".publicKeys = [
     yubikey-nfc
     yubikey-5c
     <host>
   ];
   ```

2. Generate the identity, keeping the private key off the disk:

   ```sh
   nix run nixpkgs#syncthing -- generate --home=/dev/shm/st
   ```

   Note the device ID from the "Calculated device ID" line.

3. Encrypt the key, keep the public certificate, delete the plaintext. Piped input
   skips decryption, so no YubiKey is needed:

   ```sh
   cd secrets
   agenix -e syncthing-<host>-key.age < /dev/shm/st/key.pem
   cd ..
   install -m 0644 /dev/shm/st/cert.pem dots/syncthing/<host>-cert.pem
   rm -rf /dev/shm/st
   ```

4. Add the device ID to `deviceIds` in `modules/features/syncthing.nix`.

5. Include `den.aspects.syncthing` in the host's file. It syncs the default folders
   unless the host sets its own.

6. Stage the new files, because the flake can't see untracked ones, then check:

   ```sh
   git add secrets/syncthing-<host>-key.age dots/syncthing/<host>-cert.pem
   nix flake check --no-build --no-write-lock-file path:.
   ```

7. Deploy the NAS first, so it accepts the new device, then the machine:

   ```sh
   sudo nixos-rebuild switch --flake .#nas
   sudo nixos-rebuild switch --flake .#<host>
   ```

The NAS looks up each client under `den.hosts.x86_64-linux`, so a machine on another
system needs that lookup changed as well.

## Folders

By default every client syncs `Desktop`, `Documents`, `Downloads`, `Music`, `Pictures`,
`Videos`, `Projects`, LearnHarness's data and `~/.claude`, the default of
`settings.syncthing.folders`. Dotfiles stay out, because hjem links them into the Nix store
separately on each host.

`~/.claude` carries Claude Code's sessions, prompt history, memory and settings, so a
session started on one machine resumes on the other. Its `.stignore` keeps out the login,
the folders Claude Code runs files from by itself (`daemon`, `jobs`, `shell-snapshots`,
`session-env`), installed plugins, and each machine's caches and logs. `~/.claude.json` is
outside the folder and stays per machine: it holds the machine ID and caches, so each
machine asks once to trust a project. Prompt history and a session open on both machines
follow the rule under [Recovery](#recovery), so use Claude on one machine at a time.

To add a folder for every machine, add it to that default. For one machine, set the
whole list in its host file, since setting it replaces the default:

```nix
settings.syncthing.folders = {
  documents = "Documents";
  notes = "Notes";
};
```

The NAS works out its own list from the clients, so it only needs a deploy. Build
output, caches, git lock files and half-finished downloads in `Downloads` are ignored
in every folder; the patterns are `ignoreAll` and `ignores` in the same file, and hjem
and the NAS write them as each folder's `.stignore`.

## Recovery

Every folder runs with `maxConflicts = 0`: when a file changed on both machines before
they synced, the newer edit wins and the older copy is dropped without a
`.sync-conflict` file. To get a dropped edit back, copy it out of the NAS's ZFS
snapshots of `tank/services/syncthing` (hourly for a day, daily for a week, then
weekly and monthly) at `/var/lib/syncthing/.zfs/snapshot/<snapshot>/<folder-id>/`, or
restore it from the nightly restic backup.

`modules/features/proton-backup.nix` runs on the NAS at 03:00, snapshots
`tank/services/syncthing` and `tank/services/couchdb`, backs them up with restic into
`/tank/backups/restic` (14 daily, 8 weekly, 24 monthly), and mirrors the repository to
`/my-files/Backups/nas` in Proton Drive. Every Sunday it reads back 10% of the data to
check it, and Gatus shows all three under *Backups*.

Proton receives only restic's encrypted packs. The password is
`secrets/restic-password.age`, which the YubiKeys can decrypt, so a restore works
without the NAS. Sign in to Proton once on the NAS, then run the first backup by hand:

```sh
sudo proton-backup-login
sudo systemctl start restic-backups-nas
```

To restore a file locally:

```sh
sudo restic -r /tank/backups/restic --password-file /run/agenix/restic-password \
  restore latest --target /tmp/restore --include '/var/lib/syncthing/.zfs/snapshot/restic/documents/<file>'
```

Conflicts are invisible rather than impossible, so let a machine finish syncing before
you work on it, especially git repositories and LearnHarness, whose ledgers can't be
merged. Don't sync live databases such as browser profiles.

## Obsidian

The vault at `~/Notes` syncs through the LiveSync plugin into CouchDB on the NAS
(`modules/features/livesync.nix`), not through Syncthing. It sits outside every
Syncthing folder on purpose, because two sync engines on the same files would undo each
other's work. Keep any new LiveSync vault outside the synced folders too.

CouchDB lives on `tank/services/couchdb`, which has the same hourly snapshots and is
in the same nightly backup as the Syncthing data.
