# Installing a host

From a NixOS live ISO, inside a checkout of this repo. Every host defines its
disks with disko, so partitioning is part of the config rather than a manual step.

1. Partition. This destroys everything on the host's disks:

   ```sh
   sudo nix --extra-experimental-features "nix-command flakes" run \
     github:nix-community/disko -- \
     --mode destroy,format,mount --flake .#<host>
   ```

2. Place the host's age key:

   ```sh
   sudo install -d -m 0700 /mnt/etc/age
   sudo install -m 0600 /path/to/host.key /mnt/etc/age/host.key
   ```

3. Install:

   ```sh
   sudo nixos-install --flake .#<host>
   ```

## Why the key comes first

Hosts decrypt their secrets with their own key, not a YubiKey, so they need nobody
present at boot. That includes my login password (`modules/users/miko.nix`), so
a host installed without its key won't let me log in with it.

The key needs its own backup. Losing it means generating a new one and re-encrypting:
see [Changing recipients](secrets.md#changing-recipients).
