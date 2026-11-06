# Secrets

Secrets are committed encrypted with [agenix](https://github.com/ryantm/agenix),
so the repo can stay public. Each file is encrypted to both YubiKeys, which let
me edit it, and to only the hosts that need it, which decrypt it at boot with
their own key.

## Adding or editing a secret

Declare a new secret's recipients in `secrets/agenix-rules.nix` first, then:

```sh
cd secrets
agenix -e very-secret-secret.age  # opens $EDITOR
```

## Changing recipients

After changing a secret's recipients, or replacing a host key, re-encrypt
everything from `secrets/`:

```sh
agenix -r
```

## YubiKey identities

`modules/features/yubikey.nix` installs one identity file per YubiKey on every
host. `agenix` only finds `~/.ssh/id_*` by itself, so a fish wrapper picks the file
for the connected YubiKey and frees the card from gpg-agent first.

Passing `-i` skips the wrapper, so scdaemon has to be killed by hand if the card is
busy. `~/.config/age/keys.txt` holds both identities, so with it
`age-plugin-yubikey` asks for the YubiKey I'm not using on every decryption.
