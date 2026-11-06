![A bar of Oxocarbon theme colours](docs/banner.svg)

# mikos-den

My NixOS configuration for all of my machines: a desktop, a laptop and a NAS. It's
a [dendritic](https://github.com/mightyiam/dendritic) flake built on
[den](https://github.com/denful/den), where each feature is one aspect, with
[hjem](https://github.com/feel-co/hjem) managing my user files.

Worth a look:

- **Aspects:** a host is a short list of the features it includes.
  [Why it's built this way](docs/architecture.md).
- **One theme:** a single palette drives my apps, terminal and editor from
  `lib/theme`. The bar above is rendered from it too.

## How it's organised

- `modules/features/`: one feature per file, loaded automatically.
- `modules/hosts/`: what each machine includes, plus host-only settings.
- `dots/`: plain config files the modules install.
- `lib/`: helpers and the theme.
- `secrets/`: encrypted with agenix, safe to publish.

## Common tasks

```sh
# Deploy to a host
sudo nixos-rebuild switch --flake .#<host>

# Try a host in a VM first
nixos-rebuild build-vm --flake .#<host>
./result/bin/run-<host>-vm

# Map every aspect and how they relate, as a Mermaid diagram
nix eval --raw .#diagrams.overview > /tmp/mikos-den-overview.mmd

# Regenerate the colour bar after a palette change
nix eval --raw .#banner > docs/banner.svg
```

## Docs

- [Installing a host](docs/install.md)
- [Secrets](docs/secrets.md)
- [Architecture](docs/architecture.md)

MIT licensed: see [LICENSE](LICENSE).
