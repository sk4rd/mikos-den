# mikos-den

Switch to the config using flakes:

```sh
sudo nixos-rebuild switch --flake .#<host>
```

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

The identity is the YubiKey age plugin key, provisioned by
`modules/features/yubikey.nix` (PIV slot 2) at the same path on every
host. `agenix` only auto-detects `~/.ssh/id_*`, so pass it with `-i` — or
let the fish wrapper fill it in: `agenix -e very-secret-secret.age`.

## Test VM

Every host includes the `nixos-testing-vm` aspect, which sets up
`virtualisation.vmVariant`. Build and run it with:
```sh
nixos-rebuild build-vm --flake .#<host>
./result/bin/run-<host>-vm
```
