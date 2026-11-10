# Architectural and code-quality review — `mikos-den`

**Review scope:** working tree at `/home/miko/Projects/mikos-den`, including uncommitted changes. No repository files were modified during the review; no builds, deployments, formatters, or lockfile updates were run. Read-only `nix eval` was used only to check selected claims.

**Pinned context:** Den `bf2504f9f2e8621fee091335132ab3ae698cf808`, nixpkgs `4fe25e12eb9f4c744966dd3de5a05246cf098601`, hjem `8408642aa3035135fa6d70269dc93e0814e2a4f6`. Den documentation and source were read from the pinned local store copy, so the Den-specific advice below is for that revision.

---

## 1. Executive summary

The repository is in good architectural shape. The feature-first Den layout is real, not decorative: hosts are short include lists, features own their system and user halves, typed settings are used where values genuinely vary, and the four quirks have clear producers and consumers. Most files are small and readable. This is not a configuration that needs a framework rewrite.

The highest-value work is not “more Den”; it is fixing a small number of runtime correctness gaps and removing a few duplicated sources of truth:

1. **The installed Pi package is missing a runtime dependency**, so the `subagent` extension is likely broken even though the Nix wiring is correct.
2. **The media VPN health check checks the wrong qBittorrent address**, so Gatus will report the VPN as unhealthy.
3. **The restic/Proton backup units have no mount guards**, so a missing ZFS mount can silently produce an empty backup or a second empty repository.
4. **Home Assistant has mount-ordering, `aioipp` shadowing, and `default_config` issues** that can make the service fail or behave differently than the comments claim.
5. **Caddy’s admin API is left enabled** while the Caddy config holds a zone-wide Cloudflare token; this is a hardening gap worth closing.
6. **The service-route quirk is consumed by three files with duplicated merge/filter logic**, and `status` reaches into `ddns` settings instead of receiving DDNS data through the quirk flow.
7. **The two desktop hosts duplicate the same miko app list and Proton server constants**; both can move closer to the feature that owns them.

Two alarming per-file claims were checked and **rejected**:

- The claim that Plasma’s font defaults override the theme’s fonts is false at this revision: `nix eval .#nixosConfigurations.workstation.config.fonts.fontconfig.defaultFonts` returns `Inter` and `BlexMono Nerd Font Mono` first.
- The claim that the `hjem` class is unwired is false: Den’s `flakeModule` auto-imports all battery modules, including `hjem.nix`, and `nix eval .#nixosConfigurations.workstation.config.hjem.users.miko.user` evaluates to `miko`.

What should be left alone: `flake.nix`’s `evalModules`/`import-tree` shape, `lib/settings-type.nix` (a faithful copy of the documented pattern), the theme data/role split, the simple one-purpose feature files, the host include-list style, and the plain files in `dots/`.

---

## 2. Coverage

`git ls-files --cached --others --exclude-standard -- '*.nix'` found **69 Nix files**.

| Area | Files | Reviewed | Failed |
|---|---:|---:|---:|
| Root (`flake.nix`) | 1 | 1 | 0 |
| `lib/` | 6 | 6 | 0 |
| `modules/` top level | 4 | 4 | 0 |
| `modules/features/` | 51 | 51 | 0 |
| `modules/hosts/` | 3 | 3 | 0 |
| `modules/theme/` | 2 | 2 | 0 |
| `modules/users/` | 1 | 1 | 0 |
| `secrets/` | 1 | 1 | 0 |
| **Total** | **69** | **69** | **0** |

Every file is accounted for in the appendix. The non-Nix helper scripts `modules/features/media-vpn-health-check.sh`, `media-vpn-health-server.py`, `plasma-apply-look.sh`, and `plasma-vim-shortcuts.sh` were read as context for the Nix files that embed them, but are not counted as primary Nix reviews.

Limitations: no build or VM boot was performed. Findings that depend on live host state are marked as such, notably ZFS pool properties (`acltype`, `compression`), the actual qBittorrent listener, and the NAS’s live DNS/routing state.

---

## 3. Architectural map

- `flake.nix` evaluates `inputs.nixpkgs.lib.evalModules` with `import-tree ./modules` and `specialArgs.inputs`, then returns `.config.flake`. This is the documented Den-only flake shape at the pinned revision and should not be “modernised”.
- `modules/den.nix` imports Den’s flake module, sets fleet defaults, reserves `settings`, declares four quirks, and attaches the typed settings generator to `den.schema.host`.
- `modules/hosts/*.nix` declare `den.hosts.x86_64-linux.<host>` plus a host aspect. The host aspect is mostly an include list and host-only hardware/disk/network settings.
- `modules/features/*.nix` are feature aspects. Most are `nixos`-only; many also have `hjem`, `settings`, quirk contributions, or cross-entity `provides`.
- `modules/users/miko.nix` is the user aspect. `modules/theme/*` exposes `config.theme`; `lib/theme/*` holds the palette, semantic roles, types, and renderer.
- Data flow:
  - Feature aspects emit `service-routes`, `status-endpoints`, `status-heartbeats`, and `storage-datasets`.
  - `service-names`, `ddns`, `status`, and `nas-storage` consume those quirks.
  - Typed settings are declared on aspects and read as `host.settings.<aspect>`.
  - `hjem` is the user home class; cross-entity delivery uses `provides.to-hosts`, `provides.to-users`, or `provides.<user>`.
- The main complexity centers are the NAS/media stack (`media-downloads`, `media-storage`, `nas-storage`, `proton-backup`, `home-assistant`, `status`, `service-names`) and the Plasma/theme user configuration. The rest is mostly straightforward.

---

## 4. Most important cross-file findings

### 4.1 The Pi `subagent` extension is likely broken by a missing runtime package

**Category:** correctness / likely bug. **Severity:** high. **Confidence:** high on the missing dependency, medium on the exact user-visible failure.

`modules/features/ai.nix:8` installs `pkgs.pi-coding-agent`; `:15-19` links the `subagent` extension. In the pinned nixpkgs package, `pi-ai` declares and imports `@earendil-works/pi-schema`, but the package’s `postInstall` copies only nine workspace packages and does not include `pi-schema`. The installed `pi-coding-agent-1.5.0` store tree contains no `pi-schema` package. The extension imports the SDK entry, so the tool is expected to fail to register.

**Smallest fix:** add an overlay/override that restores `@earendil-works/pi-schema` into `node_modules`, or bump/pin nixpkgs to a revision whose package includes it. Keep the Nix file’s package list and links unchanged.

**Verification:** `node -e 'import("<pi-monorepo>/dist/index.js")'` should succeed; in a Pi session the tool list should include `subagent`; run one trivial subagent call.

### 4.2 Media VPN health check checks the wrong address

**Category:** correctness / likely bug. **Severity:** high. **Confidence:** high.

`modules/features/media-downloads.nix:155` sets qBittorrent’s WebUI address to `10.200.0.2` (the veth address). `modules/features/media-vpn-health-check.sh:72` requires a listener on `10.2.0.2%wg-media` (the WireGuard address). A WebUI can only bind one address, so the health check will report “qbittorrent is not listening on wg-media” every 60 seconds. Gatus’s Proton VPN endpoint then fails and ntfy alerts fire. The nft rule at `media-downloads.nix:54` that drops WebUI traffic on `wg-media` is also dead code under this binding.

**Smallest fix:** make the listener check match the actual binding (`10.200.0.2:8080`), or remove the address-specific assertion and rely on the HTTP probe. Delete or annotate the dead nft rule.

**Verification:** on the NAS, `ip netns exec media-vpn ss -H -tln | grep 8080`; `systemctl start media-vpn-health`; `cat /run/media-vpn-health/status.json` should become `ok: true`.

### 4.3 Restic/Proton backup units lack mount guards

**Category:** correctness / likely bug. **Severity:** high. **Confidence:** high.

`modules/features/proton-backup.nix:129-134` backs up `/var/lib/couchdb` into `/tank/backups/restic`; `:147-150`, `:156-164`, and `:175-184` define the backup, check, and upload units. None sets `AssertPathIsMountPoint` or `RequiresMountsFor`. The restic module’s pre-start runs `restic cat config || restic init`; if `/tank/backups/restic` is not mounted, it initializes a second empty repository on the parent dataset and the backup “succeeds.” If `/var/lib/couchdb` is not mounted, it backs up an empty directory. The Proton upload verification only checks that the newest local snapshot exists remotely, so it also passes.

**Smallest fix:** add `AssertPathIsMountPoint = [ "/var/lib/couchdb" repo ];` to the backup unit, and `AssertPathIsMountPoint = repo;` to the check and upload units. Consider backing up from a ZFS snapshot instead of the live CouchDB directory.

**Verification:** `nix eval .#nixosConfigurations.nas.config.systemd.services.restic-backups-notes.unitConfig`; then `zfs unmount tank/backups/restic && systemctl start restic-backups-notes` must fail rather than initialize.

### 4.4 Home Assistant has three separate correctness risks

**Category:** correctness / likely bugs. **Severity:** high/medium. **Confidence:** high on mechanisms, medium on impact.

1. **Mount ordering** (`modules/features/home-assistant.nix:94-102`, `:110-113`): the `noauto` mount has no `x-systemd.requires=zfs-datasets.service`, unlike `media-storage.nix:22-40`. `home-assistant.service` has both `Requires=zfs-datasets.service` and `RequiresMountsFor=/var/lib/hass`, so the mount unit and `zfs-datasets` can race. If the mount unit runs first, it fails and HA fails via `Requires=`. Add `"nofail"` and `"x-systemd.requires=zfs-datasets.service"` to the mount options, matching `media-storage`.
2. **`aioipp` shadowing** (`:7-30`, `:75`, `:83`): `"ipp"` is in `extraComponents`, so nixpkgs’ `aioipp` 0.21.0 is in `componentBuildInputs`; the custom 0.19.3 is appended to `extraBuildInputs`. The generated PYTHONPATH shows 0.21.0 before 0.19.3, so the custom pin is shadowed. Remove `"ipp"` from `extraComponents`, or override `aioipp` through the package’s `packageOverrides`.
3. **`default_config` is not implicit** (`:69`, `:71-78`): `extraComponents` replaces the nixpkgs default list, which included `"default_config"`, `"met"`, and `"esphome"`. With `config = { }`, `default_config` is not loaded. Either add `"default_config"` and `default_config = { };`, or correct the comment to say the setup is intentionally minimal.

Also worth fixing: HA ignores `X-Forwarded-For`/`X-Forwarded-Proto` unless `config.http.use_x_forwarded_for` and `trusted_proxies` are set (`:35-39`); the direct `:8123` firewall opening bypasses Caddy’s private-route guard (`:116`); and the health check rejects the onboarding redirect (`:45-46`).

**Verification:** `systemd-analyze critical-chain home-assistant.service`; inspect the generated unit’s `After=`/`Requires=`; `python -c 'import importlib.metadata; print(importlib.metadata.version("aioipp"))'` in the HA environment; check the generated `configuration.yaml` and HA log for `default_config`.

### 4.5 Caddy admin API is enabled while the config holds a zone-wide token

**Category:** security / correctness. **Severity:** medium-high. **Confidence:** high on the default, medium on threat-model relevance.

`modules/features/service-names.nix:72-83` configures Caddy without `globalConfig` or `enableReload`. nixpkgs defaults `enableReload = true`, and Caddy’s default admin endpoint is `localhost:2019`, unauthenticated. Any local service user can POST a new config to `/load`, removing the `@external` guard or reading `{file./run/agenix/cloudflare-dns-token}`. The token is zone-wide. This requires local code execution as a service user, but the NAS runs several internet-facing/downloading services.

**Smallest fix:** `services.caddy.globalConfig = "admin off";` and `services.caddy.enableReload = false;` (Caddy restarts on config change), or bind the admin API to a restricted Unix socket.

**Verification:** from a non-root service user, `curl -s http://localhost:2019/config/` returns JSON before and connection refused after; `systemctl reload caddy` fails after, while `systemctl restart caddy` works.

### 4.6 The `service-routes` quirk is consumed three times with duplicated logic

**Category:** Den idiom / complexity. **Severity:** medium. **Confidence:** high.

`modules/features/service-names.nix:32-33`, `modules/features/ddns.nix:31-33`, and `modules/features/status.nix:53-55` each fold `service-routes` with `acc // entry` and filter `public = true`. `status` also reads `host.settings.ddns.extraNames` (`status.nix:55`) but does not include `ddns` (`status.nix:31-34`). The result is three copies of the route merge/filter rule and a hidden cross-aspect settings read.

**Simplest structural fix:** add a small `lib/service-routes.nix` helper with `merge = lib.mergeAttrsList` and `publicNames`, and use it in all three consumers. Better Den-wise: have `ddns` contribute its DDNS checks through `status-endpoints` (or a dedicated quirk), so `status` does not read `ddns` settings. At minimum, add `den.aspects.ddns` to `status.includes` so the dependency is explicit.

**Tradeoff:** a helper adds one file but centralizes the security-relevant `public` predicate. Moving DDNS checks into `ddns` adds a quirk but removes the cross-aspect settings read.

### 4.7 Desktop host duplication and hidden bundle contracts

**Category:** complexity / Den idiom. **Severity:** medium. **Confidence:** high.

`modules/hosts/workstation.nix:19-25` and `modules/hosts/thinkpad-z13.nix:24-30` contain the identical five-entry miko app list (`gh`, `obsidian`, `learnharness`, `voxtype`, `ai`). Both hosts include `desktop`, so the list can move to `den.aspects.desktop.provides.miko.includes`. Similarly, the Proton server `publicKey`/`endpoint` values are duplicated in both host files (`workstation.nix:7-8`, `thinkpad-z13.nix:11-12`); give the feature defaults and leave only `secret` per host.

`modules/features/desktop.nix:15` includes `proton-vpn-client`, whose three settings are required. The bundle is therefore not self-contained; a new host that includes `desktop` must also set `settings.proton-vpn-client.*`. Document that contract or move the VPN include to the hosts.

**Verification:** compare `nix eval --json .#nixosConfigurations.{workstation,thinkpad-z13}.config.hjem.users.miko.packages` before/after; compare the generated NetworkManager profile store paths.

### 4.8 Several aspects are not self-contained

**Category:** Den idiom / complexity. **Severity:** medium. **Confidence:** high.

Examples:

- `livesync.nix` contributes `storage-datasets` and hard-`Requires=zfs-datasets.service`, but does not include `nas-storage` (`livesync.nix:14-39`, `:85-88`).
- `proton-backup.nix` emits `status-heartbeat@…` references but does not include or document `status` (`proton-backup.nix:107-110`).
- `status.nix` reads `ddns` settings but does not include `ddns` (`status.nix:55`).
- `service-names.nix` declares the Cloudflare secret but does not include `secrets`; `ddns.nix` includes `service-names` mainly to obtain that secret, which also pulls in Caddy (`ddns.nix:5`, `service-names.nix:55-88`).
- `wireguard-server.nix` uses `age.secrets` but relies on the global `secrets` include (`wireguard-server.nix:43`, `:48`).

Some of these are harmless because the host includes both sides today. The risk is reuse: a feature included on another host silently loses its dataset/route/status data or fails at runtime. The smallest robust change is to add the hard dependency (`livesync` → `nas-storage`) and document the soft ones; do not add heavy includes like `status` to every backup host unless that is intended.

### 4.9 Conditional runtime issue: media-storage ACLs require `tank` to have `acltype=posixacl`

**Category:** correctness / likely bug. **Severity:** medium-high, conditional. **Confidence:** medium.

`modules/features/media-storage.nix:70` is the only `setfacl` in the repo. `tank` is not managed by disko; only `rpool` gets `acltype = "posixacl"` (`modules/hosts/nas.nix:97`). If `tank` was created with ZFS’s default `acltype=off`, `setfacl` fails with `ENOTSUP`, `media-storage.service` fails under `set -eu`, and every media service that requires it fails. This cannot be confirmed from the repo alone.

**Smallest fix:** add a runtime check in `media-storage.service` (`zfs get -H -o value acltype tank` must be `posixacl`) or switch to the setgid/group scheme already used in `media-downloads.nix:108`. Also pin the `media` GID (`users.groups.media.gid`) because ACLs store numeric GIDs and the gid-map lives on `rpool`, not `tank`.

**Verification:** on the NAS, `zfs get acltype tank`, `getfacl /tank/data/media`; if `acltype=off`, the current service cannot work.

### 4.10 Secondary but real issues worth batching

- `flatpak.nix:7-14`: `Type=simple` and only `After=network.target`; first boot can fail before DNS. Add `network-online.target` + `Type=oneshot`, or a retry.
- `nixos-testing-vm.nix:22-25`: only `miko-password` is disabled; other host secrets remain enabled and agenix activation fails without `/etc/age/host.key`. Use `age.enable = lib.mkForce false;`.
- `audio.nix:4-8`: `services.pipewire` is enabled without `security.rtkit`, so user audio threads may not get realtime priority.
- `ghostty.nix:15`: `selection-background` is set but `selection-foreground` is not; selected text can be very low contrast.
- `nas-vpn-client.nix:38,48,56`: `autoconnect = true` plus `allowed-ips = 192.168.178.0/24` can hijack a foreign LAN with the same subnet; add a high `ipv4.route-metric`.
- `servarr.nix:56-60`: prowlarr’s UID/GID are not pinned even though its state lives on a persistent dataset; a reinstall can orphan ownership.
- `ddns.nix:32-34,70-96`: records are created/updated but never deleted, and one bad name aborts all later updates.
- `keyboard.nix:25-28,39`: the local udev rule duplicates the keyboard-hud module’s default rule; rely on the module default.
- `voxtype.nix:27-28`: the multiline `initial_prompt` includes a newline and 12 spaces in the TOML value.

---

## 5. Prioritized simplification roadmap

### P0 — correctness/security fixes, high benefit, low-to-medium risk

| Change | Files | Why first | Risk |
|---|---|---|---|
| Fix Pi `pi-schema` packaging | `modules/features/ai.nix` + overlay or nixpkgs bump | The subagent extension is a headline feature and is likely non-functional | Medium: package override needs testing |
| Fix media VPN listener check | `media-vpn-health-check.sh`, `media-downloads.nix` | Gatus/ntfy currently report a permanent false failure | Low |
| Add restic/Proton mount guards | `proton-backup.nix` | Prevents silent empty backups / second repositories | Low |
| Fix HA mount ordering and `aioipp` shadowing | `home-assistant.nix` | HA can fail at boot or load the wrong `aioipp` | Low-medium |
| Disable Caddy admin API or restrict it | `service-names.nix` | Zone-wide DNS token is reachable from local services | Low; loses reload-on-change |
| Verify/fix `tank` ACL prerequisite | `media-storage.nix`, `nas.nix` | If `acltype=off`, the whole media stack fails | Low code, needs live check |

### P1 — safe local cleanups

- Add `security.rtkit.enable = true` to `audio.nix`.
- Add `selection-foreground` to `ghostty.nix`.
- Make the voxtype prompt a single line.
- Add `lib.unique` to `status.nix` DDNS names and trim in `slug`.
- Add heartbeat-id uniqueness/allowed-character assertions in `status.nix`.
- Use `services.caddy.openFirewall = true` and `owner = config.services.caddy.user` in `service-names.nix`.
- Use `lib.mkDefault` for `den.default.nixos.system.stateVersion` in `den.nix`, and for the locale timezone if hosts should be able to override it.
- Add `Type = "oneshot"` and `network-online.target` to `flatpak-repo`.
- Replace `age.secrets.miko-password.enable` with `age.enable = lib.mkForce false` in `nixos-testing-vm.nix`.
- Remove the duplicate keyboard udev rule or the `hidrawAccess = false` override.
- Pin prowlarr’s UID/GID in `servarr.nix`.
- Add `ipv4.route-metric` to `nas-vpn-client.nix`.
- Fix the `ddns` fail-fast loop to continue per name, and document that removed records are not deleted.
- Add `AssertPathIsMountPoint` to `proton-backup` units.
- Add `admin off`/`enableReload = false` to Caddy if the admin API is not needed.

### P2 — structural simplifications

1. **Centralize service-route merging/filtering.** Add `lib/service-routes.nix` with `merge` and `publicNames`; use it in `service-names`, `ddns`, and `status`. This removes three copies of a security-relevant predicate.
2. **Move DDNS monitoring into `ddns`.** Have `ddns` contribute its own `status-endpoints` (or a `ddns-names` quirk), so `status` no longer reads `host.settings.ddns.extraNames`. This removes the hidden `status` → `ddns` coupling.
3. **Move the miko desktop app list to `desktop.provides.miko.includes`.** Remove the identical list from both host files.
4. **Give `proton-vpn-client` defaults for `publicKey`/`endpoint`.** Remove the duplicated constants from both hosts.
5. **Make `livesync` include `nas-storage`.** It hard-requires `zfs-datasets.service`; the dataset consumer should travel with the feature. Document the `status`/`proton-backup` relationship rather than pulling the whole status stack.
6. **Unify the media-storage ownership mechanism.** Choose either ACLs or setgid/group ownership; today the repo uses both. If ACLs stay, pin the `media` GID and add the `acltype` check.
7. **Reduce media-downloads literal duplication.** Introduce `webuiAddress`/`webuiPort` bindings for the route, endpoint, and Python config; keep the nft ruleset literals with a comment.
8. **Simplify NAS dataset property handling.** Use `lib.mergeAttrsList` instead of the manual fold, and consider a default `props` in `datasetBlock` so `tank/private` does not silently miss compression.
9. **Standardize the host→user delivery mechanism.** The repo uses plain `hjem` + `host-aspects`, `provides.to-users`, and `provides.miko.hjem`. Pick one rule; do not churn individual files until the rule is decided.

### P3 — product/behavior decisions (do not “fix” without a decision)

- Should Home Assistant load `default_config` or remain minimal?
- Should HA be reachable directly on `:8123`, or only through Caddy?
- Should downloads live on `tank/data/media/downloads` (same filesystem as the library) or `tank/data/torrents` (quota)? The current quota dataset is unused.
- Should the NAS user get GUI apps (`ghostty`, `vesktop`) and a Qt pinentry, or should those be desktop-host-only?
- Should passwordless sudo remain on the NAS?
- Should `wg0` remain a fully trusted firewall interface, or should internal services be allowed per port?
- Should the LAN IPv6 prefix be added to `service-names.internalRanges`, or should IPv6 be disabled on the NAS?
- Should `proton-backup` back up a live CouchDB directory or a ZFS snapshot?
- Should `miko-password` be granted to every host, or is a static hash acceptable on some hosts?

### P4 — speculative / low priority

- Remove or wire `theme.palette`, `theme.variant`, and unused `theme.lib` helpers.
- Move generated btop/vesktop/fish configs into `lib/theme/render/` if the “generated theme files live there” rule is meant strictly.
- Add a flake check that `docs/banner.svg` matches `flake.banner`.
- Add a check that only `lib/theme/oxocarbon.nix` contains hex literals.
- Convert `provides.*` to `den.policies` where it materially clarifies routing; do not do this mechanically.

---

## 6. Verification plan

Use the repository’s own facilities, in increasing cost order:

1. **Formatting/eval-only**
   - `nix flake check` — currently only the formatting check; expect it may already fail on pre-existing unformatted files.
   - `nix eval --raw .#diagrams.overview > /tmp/overview.mmd`
   - `nix eval --raw .#banner > /tmp/banner.svg`
   - Targeted `nix eval` for changed options, e.g.:
     - `nix eval .#nixosConfigurations.nas.config.services.caddy.virtualHosts`
     - `nix eval .#nixosConfigurations.nas.config.services.gatus.settings`
     - `nix eval .#nixosConfigurations.nas.config.systemd.services.restic-backups-notes.unitConfig`
     - `nix eval .#nixosConfigurations.workstation.config.fonts.fontconfig.defaultFonts`
     - `nix eval .#nixosConfigurations.workstation.config.hjem.users.miko.packages`

2. **Per-host VM evaluation**
   - `nixos-rebuild build-vm --flake .#nas`
   - `nixos-rebuild build-vm --flake .#workstation`
   - `nixos-rebuild build-vm --flake .#thinkpad-z13`
   - Boot the VM where the change affects boot ordering, mounts, services, or user sessions.

3. **Runtime checks on the NAS**
   - `systemctl status media-vpn media-vpn-health qbittorrent`
   - `cat /run/media-vpn-health/status.json`
   - `ip netns exec media-vpn ss -H -tln | grep 8080`
   - `systemctl status var-lib-hass.mount home-assistant.service`
   - `systemd-analyze critical-chain home-assistant.service`
   - `zfs get acltype,compression,recordsize tank tank/data/media tank/private`
   - `getfacl /tank/data/media`
   - `systemctl start restic-backups-notes` after unmounting `tank/backups/restic`; it must fail, not initialize.
   - `curl -s http://localhost:2019/config/` from a non-root service user; should be refused after the Caddy hardening.
   - `flatpak remotes`, `journalctl -b -u flatpak-repo.service`
   - `ip route get 192.168.178.1` with the NAS VPN up; check the route metric.

4. **Runtime checks on a desktop**
   - `fc-match sans-serif`, `fc-match monospace`
   - `ghostty +show-config` and a text selection check
   - `systemctl --user status plasma-no-idle-sleep.service`
   - `systemctl --user status voxtype`
   - `cat ~/.config/voxtype/config.toml`
   - `ls -l ~/.gitconfig` and a `git config --global` write test if runtime edits are expected.

5. **Pi**
   - `node -e 'import("<pi-monorepo>/dist/index.js")'`
   - Start Pi and confirm `subagent` appears in the tool list; run one trivial subagent call.

---

## 7. Per-file appendix

Legend: **C** correctness/likely bug, **D** Den idiom, **N** Nix idiom, **X** complexity, **P** subjective preference. Severity is the reviewer’s assessment; conditional findings are marked.

### Root and library

- **`flake.nix`** — flake output. **Preserve:** the `evalModules` + `import-tree` + `specialArgs.inputs` + `.config.flake` shape; input names are load-bearing. **Findings:** (X, medium) `nixpkgs-brave` tracks `master` and can drift from the pinned nixpkgs; pin it to a rev or update both together (`flake.nix:6-7`, `modules/features/brave.nix:5-10`). (N, info) `nixpkgs-unstable` is package-tested, not NixOS-module-tested; `nixos-unstable` is the safer branch if desired. **Unresolved:** whether the Brave skew is accepted.
- **`lib/settings-type.nix`** — settings generator. **Preserve:** faithful copy of Den’s documented helper; name-based skipping is load-bearing. **Findings:** (D, medium) one `settings` block per aspect; a second block silently replaces the first (`:15`, `:22`; Den docs). Add a comment or use `settings.imports`. (X, low) no provenance comment for the vendored helper. (N, low) `reshape` reserves `options`/`config`/`imports`; document or assert. **Unresolved:** whether settings should also attach to users.
- **`lib/disks/encrypted-ext4.nix`** — disk helper. **Preserve:** pure function, LUKS2/ext4 layout, `allowDiscards`, ESP options. **Findings:** (X, low) ESP block duplicates `nas.nix:60-73` except size; extract an `esp.nix` helper if touched. (P, info) comment the TRIM tradeoff. (N, info) `--type=luks2` is redundant on current cryptsetup. **Unresolved:** 1G vs 2G ESP; no swap/hibernation is intentional?
- **`lib/theme/default.nix`** — semantic theme data. **Preserve:** roles over raw palette, ANSI order, font attr-paths. **Findings:** (X, low) `ansiNamed` and `ansi` duplicate the 16 values; derive `ansi` from an ordered name list. (X, low) `colors.cyan/magenta` differ from ANSI slot names; add a comment. (X, low) `theme.palette` is unused escape hatch; drop or document. (N, low) `theme.lib` holds functions and is not serializable; drop `hexByte` or document. **Unresolved:** palette provenance revision; font names need runtime check.
- **`lib/theme/oxocarbon.nix`** — raw palette. **Preserve:** plain data, single source of hex literals, all keys used. **Findings:** (P, low) `baseNN` are not base16 slots; add a comment. (N, info) no check enforces the “only hex literals here” rule. (P, info) Carbon provenance comment is slightly broader than the data. **Unresolved:** confirm `blend`/diff backgrounds against upstream.
- **`lib/theme/types.nix`** — theme option type. **Preserve:** `hexColor`, name character class, ANSI length check, pkgs-free font paths. **Findings:** (N, low) `ansiNamed` has no key-set constraint while `ansi` has length 16; derive both from one ordered list. (X, low) `palette` is unused. (X, low) `variant` is unreachable because `theme` is read-only and only dark exists. (N, info) `theme.lib` is `attrsOf raw`; use `functionTo` if desired. (N, info) `font.package = [ ]` passes; use `nonEmptyListOf`. **Unresolved:** is a light variant planned?
- **`lib/theme/render/banner.nix`** — SVG renderer. **Preserve:** pure `{ lib, theme }`, 10-block layout, `imap0`. **Findings:** none. **Unresolved:** is omitting `lightBlue` intentional? Should `docs/banner.svg` be checked against `flake.banner`?
- **`modules/den.nix`** — Den wiring. **Preserve:** central quirk registry, documented settings hookup, `hostname` default. **Findings:** (N, low) `den.default.nixos.system.stateVersion` should be `lib.mkDefault` so a host can override without `mkForce` (`:11`). (X, low) comment the reciprocal dependency between `den.reservedKeys = [ "settings" ]` and `lib/settings-type.nix` (`:13-14`, `:21-29`). (P, info) the comment says “child aspect”; the actual failure is class-content wrapping. **Unresolved:** whether `hostname` should be a schema default instead of `den.default`.

### Top-level modules and theme/user

- **`modules/banner.nix`** — flake output. **Preserve:** thin wiring, pure renderer. **Findings:** (P, low) “by hand” comment is misleading; name the `nix eval` command. **Unresolved:** should the committed SVG be checked?
- **`modules/diagrams.nix`** — flake output. **Preserve:** lazy namespace graph, `ofNamespace` args. **Findings:** (X, low) `flattenEntityKinds` may be inert on a namespace graph; comment or diff output before dropping. (X, low) no header comment. (X, info) no check exercises the diagram. **Unresolved:** is the fold load-bearing?
- **`modules/formatter.nix`** — formatter/check. **Preserve:** single treefmt eval, per-language config, `inputs.self` check. **Findings:** (N, low) `settings.global.excludes` is a deprecated alias; use `settings.excludes` (`:30-34`). (X, low) shfmt `simplify` defaults true and is undocumented; make it explicit. **Unresolved:** TS files not formatted; taplo/ruff may have no targets.
- **`modules/theme/aspect.nix`** — theme aspect. **Preserve:** theme roles, font packages, console palette mapping. **Findings:** none substantive. The reported font-order bug was checked and does **not** reproduce: `nix eval …fonts.fontconfig.defaultFonts` returns `Inter`/`BlexMono` first. (X, low) header says “fonts” but also sets the VT palette; update the comment. (X, info) `config.theme` is flake-level, not inside the NixOS module; document. **Unresolved:** should the VT palette apply to non-desktop hosts?
- **`modules/theme/option.nix`** — theme option. **Preserve:** single read-only entry point, lazy default. **Findings:** (D, low) “every module as `config.theme`” is only true for flake-level modules; class modules must capture it (`:1`). (N, info) `readOnly` + default makes `variant` unreachable; confirm intent. (P, info) option description carries a repo convention; move it to docs. **Unresolved:** per-host theming planned?
- **`modules/users/miko.nix`** — user aspect. **Preserve:** user class for account settings, `provides.to-hosts` password, batteries, feature includes. **Findings:** (D, low) `den.schema.user.classes = lib.mkDefault [ "hjem" ]` is fleet-wide and belongs in `den.nix` (`:4`). (X, low) ghostty/vesktop are included for the headless NAS; move to desktop hosts if unintended (`:13,15`). (X, low) `.gitconfig` is split with `git.nix`; document the merge contract (`:19-23`). (X, info) full name duplicated (`:21,27`). (P, info) `createHome` restates a default. **Unresolved:** should miko’s home be identical on the NAS?

### Hosts

- **`modules/hosts/nas.nix`** — host aspect. **Preserve:** host/settings split, short includes, host-only disko/network. **Findings:** (X, medium) `tank` is not declared or documented; only `rpool` is in disko (`:53-124`, `nas-storage.nix:60,131`). Add a comment or declare the pool. (P, medium) passwordless sudo on a public-facing host (`:130`); scope or document. (X, low) peer labels lost; restore comments (`:9-23`). (X, low) `enp1s0` repeated four times (`:8,136,138,140`). (X, low) `vpn.sk4rd.com` duplicated with `nas-vpn-client.nix:47`. (N, low) unnecessary `nixos = { ... }:`. **Unresolved:** is `tank` manually managed? Is passwordless sudo intentional?
- **`modules/hosts/thinkpad-z13.nix`** — host aspect. **Preserve:** host/settings split, nixos-hardware import, short includes, disk helper. **Findings:** (D, low) `settings.proton-vpn-client` is set but the aspect is only included transitively via `desktop`; add it explicitly (`:10-14`, `:18-22`). (X, low) Proton server constants duplicated with workstation (`:11-12`). (X, info) `fwupd`/`power-profiles-daemon` are already enabled by Plasma; keep as intent or drop. **Unresolved:** WireGuard address has no shared source of truth; is `tiny_power_button` still needed?
- **`modules/hosts/workstation.nix`** — host aspect. **Preserve:** host/settings split, no-idle-sleep comment, host-only hardware. **Findings:** (X, low) miko app list duplicated with thinkpad (`:19-25`); move to `desktop.provides.miko.includes`. (X, low) Proton constants duplicated (`:7-8`). (X, low) `plasma-no-idle-sleep` silently does nothing if powerdevil is absent; want it by `graphical-session.target` or document (`:32-41`). (P, low) keyboard comment says Meta+Alt+K but host uses F10 (`modules/features/keyboard.nix:30`). (P, info) bare F10/Shift+F10 conflict with app shortcuts. **Unresolved:** should no-idle-sleep be a plasma setting?

### Features

- **`modules/features/ai.nix`** — aspect. **Preserve:** unfree battery, hjem package/file split, individual links. **Findings:** (C, high) `pi-coding-agent` lacks `@earendil-works/pi-schema`, which `pi-ai` imports; the subagent extension is likely broken (`:8,15-19`). Fix via overlay or nixpkgs bump. (X, low) 13 file entries repeat target/source; use `lib.genAttrs` if desired. (N, low) line 15 is not nixfmt-wrapped. **Unresolved:** overlay vs nixpkgs bump.
- **`modules/features/audio.nix`** — aspect. **Preserve:** minimal PipeWire/ALSA/Pulse trio. **Findings:** (C, medium) `security.rtkit` is not enabled; user PipeWire may lack realtime priority (`:4-8`). Add `security.rtkit.enable = true;`. **Unresolved:** is RT actually granted today?
- **`modules/features/bluetooth.nix`** — aspect. **Preserve:** opt-in via `desktop`, simple options. **Findings:** none. `powerOnBoot = true` is the nixpkgs default (`:6`); keep as a pin or drop. **Unresolved:** should Bluetooth be desktop-wide or per-host?
- **`modules/features/brave.nix`** — aspect. **Preserve:** policy payload, extension IDs, MIME defaults. **Findings:** (N, medium) imports a `chromium.nix` module from moving `nixpkgs-brave` into the pinned nixpkgs eval; pin or document (`:6-7`). (X, low) the imported module also writes Chromium/Chrome policies, not just Brave; comment (`:6-7`). (X, low) package comes from a second nixpkgs; comment why (`:9-11`). (N, low) relative `disabledModules` assumes the pinned `modulesPath`. **Unresolved:** Plasma browser integration native messaging; should Brave be a user package?
- **`modules/features/common-utils.nix`** — aspect. **Preserve:** theme-driven btop/bat, read-only btop config, self-registration. **Findings:** (C, low) `inactive_fg = c.muted` is very dark; `dim` is the intended inactive role (`:20`). (C, low) six btop theme keys are missing (`:12-57`). (X, info) git/ripgrep duplicated with `git.nix`/`neovim.nix` (`:66,73`). **Unresolved:** should btop renderer move to `lib/theme/render/`?
- **`modules/features/desktop.nix`** — aggregate aspect. **Preserve:** pure composition, host-level scope. **Findings:** (D, low) `kicad` is delivered to all users via `provides.to-users` (`:8`, `kicad.nix:4`); move to `provides.miko` if it is miko-only. (X, low) `proton-vpn-client` has required settings but the bundle does not say so (`:15`); comment or move. (X, info) boundary between host apps and user apps is implicit; add comments. **Unresolved:** should KiCad be per-user? Should Plasma’s terminal be user-scoped?
- **`modules/features/disko.nix`** — aspect. **Preserve:** single import responsibility, static aspect. **Findings:** (D, medium) every host that sets `disko.devices` must also include this aspect; other infrastructure aspects self-register (`:4`). Add `den.schema.host.includes` or document. (X, low) add a comment that layouts live in host files. **Unresolved:** should disko be a schema default?
- **`modules/features/fish.nix`** — aspect. **Preserve:** `set -g` in `conf.d`, bare hex, modifier syntax. **Findings:** (N, low) alias `h` for `theme.lib.bare` is unexplained; use `inherit (config.theme.lib) bare` (`:5`). (D, low) name suggests full fish setup but only colours; comment or rename. (P, info) `fish_color_keyword` duplicates the command fallback. **Unresolved:** search-match vs selected-background role.
- **`modules/features/flatpak.nix`** — aspect. **Preserve:** opt-in via desktop, `--if-not-exists`, `wantedBy multi-user`. **Findings:** (C, medium) unit is `Type=simple` and only `After=network.target`; first boot can fail before DNS (`:7-14`). Add `network-online.target` + `Type=oneshot`, or retry. (N, low) `xdg.portal.enable` is required by flatpak but supplied only by Plasma (`:4-5`); add it to the aspect. (N, info) use `config.services.flatpak.package`. **Unresolved:** background retry vs boot guarantee; pin Flathub repo?
- **`modules/features/fzf.nix`** — aspect. **Preserve:** `bg:-1`, `#rrggbb` colors, self-registration. **Findings:** (X, low) `fzf --fish | source` runs in non-interactive fish; guard with `status is-interactive` (`:35-40`). (P, low) `bg+` uses `surface` while other selections use `selection`/`overlay` (`:16`). (D, info) fish-specific file from a generic-named aspect; comment. **Unresolved:** is dimmer `bg+` intentional?
- **`modules/features/gaming.nix`** — aspect. **Preserve:** narrow unfree list, `extraPackages`, desktop inclusion. **Findings:** (C, low) MangoHud is installed but not enabled; it only works per game via `mangohud %command%` (`:15`). If always-on is intended, override `programs.steam.package` with `extraEnv.MANGOHUD = true`. **Unresolved:** always-on vs per-game; should gaming be desktop-wide?
- **`modules/features/gh.nix`** — aspect. **Preserve:** package-only scope, function form for `pkgs`. **Findings:** none. **Unresolved:** gh is desktop-only via `provides.miko`; is that intended?
- **`modules/features/ghostty.nix`** — aspect. **Preserve:** host `TERMINAL` + hjem config, theme-generated palette, kglobalaccel file. **Findings:** (C, medium) `selection-background` is set but `selection-foreground` is not; selected text can be low contrast (`:15`). Add `selection-foreground = c.fg` or `c.dim`. (X, low) `shell-integration = fish` duplicates the login-shell choice (`:33`); use `detect` or comment. (C, low) the font package comes only from `theme`, which the NAS does not include (`:31`, `theme/aspect.nix:14-17`); document or include the font. (P, info) `with pkgs;` for one package. **Unresolved:** is the kglobalaccel directory correct? Should ghostty be on the NAS?
- **`modules/features/git.nix`** — aspect. **Preserve:** generic settings split from identity, hjem `lines` merge. **Findings:** (X, low) `pkgs.git` duplicates `common-utils.nix:66` (`:3`). (C, low) `.gitconfig` is a store symlink; `git config --global` will fail or replace it (`:5-10`). Set `type = "copy"` if runtime edits are expected, or document declarative-only. **Unresolved:** should generic git settings apply to all users?
- **`modules/features/home-assistant.nix`** — aspect. **Preserve:** feature shape, local `aioipp` helper, dataset/route/status contributions, service hardening. **Findings:** (C, high) mount unit has no `x-systemd.requires=zfs-datasets.service`, so it can race the dataset creation (`:94-102`, `:110-113`). (C, high) custom `aioipp` 0.19.3 is shadowed by nixpkgs 0.21.0 because `"ipp"` is in `extraComponents` (`:7-30`, `:75`, `:83`). (C, medium) `default_config` is not implicit; the comment is wrong and the integration is not loaded (`:69`, `:71-78`). (C, medium) `radio_browser` onboarding deps are missing (`:72-91`). (C, medium) HA ignores `X-Forwarded-For`/`Proto` without `use_x_forwarded_for`/`trusted_proxies` (`:35-39`). (P, medium) direct `:8123` firewall opening bypasses Caddy’s guard (`:116`). (C, low) health check rejects onboarding 302 (`:45-46`). (X, low) dataset mountpoint duplicates `stateDir` (`:52`). **Unresolved:** is `default_config` intended? Is direct `:8123` intended? Does HA 2026.10.4 work with `aioipp` 0.21.0?
- **`modules/features/intel-qsv.nix`** — aspect. **Preserve:** `hardware.graphics.enable`, three-package Intel stack, Jellyfin-only inclusion. **Findings:** (D, low) `hardware.enableRedistributableFirmware` is host-wide but gated on Jellyfin (`:5`); comment or move to `nas.nix`. (X, info) `intel-compute-runtime` is for tone mapping; comment (`:12`). **Unresolved:** NAS CPU generation; is `linux-firmware` needed for the NIC?
- **`modules/features/keyboard.nix`** — aspect + flake package. **Preserve:** keyboard-hud import, EurKEY layout, firmware package, flashing comment. **Findings:** (X, medium) local udev rule duplicates the keyboard-hud module’s default and is disabled via `hidrawAccess = false` (`:25-28,39`); delete both or keep one. (C, low) comment says Meta+Alt+K but workstation uses F10 (`:30`). (N, info) `variant = ""` is a no-op (`:22`). (D, low) flake package hardcodes `x86_64-linux`; use a `packages` aspect if desired (`:12-13`). **Unresolved:** layout.json is not provisioned; should HUD be workstation-only?
- **`modules/features/kicad.nix`** — aspect. **Preserve:** correct `provides.to-users` for a host-included package, no unfree needed. **Findings:** no substantive bug. The reported “hjem class unwired” claim is **rejected**: Den’s flakeModule auto-imports the hjem battery, and `nix eval …hjem.users.miko.user` works. (D, low) mechanism differs from other user-package features; decide whether KiCad is per-user or all-users. (P, info) `kicad-small` avoids the 3D model closure if the viewer is unused. **Unresolved:** per-user vs all-users; is 3D used?
- **`modules/features/learnharness.nix`** — aspect. **Preserve:** AppImage wrapper, `--replace-fail`, manual desktop/icon install. **Findings:** (X, low) no comments explaining why an AppImage and why the icon copy is needed (`:4-27`). (N, low) `cp -r …/icons $out/share/icons` can create `icons/icons` if the target exists (`:23`); use `mkdir -p` + `cp -r …/.` or install the single icon. (C, info) x86_64 asset is unguarded (`:10`). **Unresolved:** Electron sandbox for terminal launches; license metadata.
- **`modules/features/livesync.nix`** — aspect. **Preserve:** secret-gated enable, CouchDB config, dataset/route/status contributions, mount assert. **Findings:** (D, medium) no `includes = [ nas-storage ]` despite hard `Requires=zfs-datasets.service` (`:14-39,85-88`); add it. (C, low) `[httpd]` config is dead on CouchDB 3.5.2; `WWW-Authenticate` belongs in `[chttpd]` (`:74-77`). (X, low) `dataDir` is not passed to `databaseDir`/`viewIndexDir` (`:9,16,88`). (X, low) `/_up` accepts 401; could use `require_valid_user_except_for_up` and check 200 (`:38`). (X, info) `enabled` is private, so `proton-backup` cannot see it (`:8`). **Unresolved:** how do internal service names resolve? Is `require_valid_user_except_for_up` compatible with the current auth config?
- **`modules/features/locale.nix`** — aspect. **Preserve:** self-registration, deliberate `en_US`/`de_DE` split. **Findings:** (X, low) `extraLocales` duplicates locales already derived from `extraLocaleSettings` (`:7`). (D, low) timezone/default locale should be `lib.mkDefault` if hosts may override (`:6,24`). (P, low) `LC_COLLATE = de_DE` changes sort/glob behavior globally (`:20`). **Unresolved:** was `GTK_IM_MODULE` intentionally dropped?
- **`modules/features/media-downloads.nix`** — aspect. **Preserve:** killswitch netns, nft default-drop, qBittorrent sandboxing, `bindsTo`/`partOf`, mount asserts. **Findings:** (C, high) health check expects `10.2.0.2%wg-media` but WebUI binds `10.200.0.2` (`:155`, `media-vpn-health-check.sh:72`); Gatus always fails. (C, medium) downloads go to `/tank/data/media/downloads`, but the quota is on unused `tank/data/torrents` (`:109-111,149-150,185`; `nas-storage.nix:35-41`). (X, low) 8080/addresses repeated many times; bind them in a `let`. (N, low) `requires` includes `media-vpn.service` already covered by `bindsTo` (`:121-125`). (X, low) `preStart` and `services.qbittorrent.serverConfig` can both write `qBittorrent.conf`; document or consolidate (`:133-171`). (X, info) `postStop` deletes `wg-media` in the host namespace where it does not exist (`:84`). (P, info) comment says the WireGuard socket stays in the host namespace; it moves with the device (`:72`). **Unresolved:** quota path decision; is `PrivateUsers` + `NetworkNamespacePath` working? Are downloads/movies/shows used?
- **`modules/features/media-storage.nix`** — aspect. **Preserve:** dataset contribution, mount asserts, `media` group, ACL setup. **Findings:** (C, high conditional) `setfacl` requires `tank` to have `acltype=posixacl`; only `rpool` is declared (`:70`, `nas.nix:97`). Add a runtime check or use setgid. (C, medium) `media` GID is not pinned; ACLs store numeric GIDs and gid-map is not on `tank` (`:19`). (C, low) default ACL `rwx` applies to files; use `rwX` (`:70`). (X, medium) ACLs and setgid/UMask are both used in the media stack; choose one (`:9,19,70`, `media-downloads.nix:108`, `servarr.nix:80`). (X, low) mount paths repeated; bind them. (X, low) comment blames `noauto` for emergency mode; `nofail` is the relevant option (`:21`). (X, low) `props` duplicates `nas-storage` defaults and uses 128K for SQLite state (`:11-14`). **Unresolved:** live `zfs get acltype tank`; is ACL approach deliberate?
- **`modules/features/media-vpn-health.nix`** — aspect. **Preserve:** self-contained include, status endpoint, freshness window, root check vs dynamic HTTP server. **Findings:** (X, medium) port/path `9188`/`/health` are duplicated between Nix and Python (`:10`, `media-vpn-health-server.py:6,12,37`); bind them once. (N, low) `DynamicUser` implies `ProtectSystem=strict`/`NoNewPrivileges`; `PrivateTmp = true` weakens the implied `disconnected` mode (`:85-88`). (N, low) `zfs` appears in `makeBinPath` and again as `/sbin` (`:39,42`). (N, low) use `config.boot.zfs.package`/`config.systemd.package` for version consistency (`:36,39`). (C, low) status JSON is truncated before writing; write to a temp file and rename (`media-vpn-health-check.sh:93-117`). **Unresolved:** does the listener assertion match libtorrent’s actual bind? Is `[BODY].ok == true` accepted by Gatus 5.38.0?
- **`modules/features/nas-storage.nix`** — aspect. **Preserve:** single writer, pool guard, idempotent property updates, base-vs-contribution assertion, sanoid templates. **Findings:** (C, medium) `requires = [ "zfs-import.target" ]` does not pull `zfs-import-tank.service`; the tank import is only pulled by noauto mount units (`:175-179`). Add `zfs-import-tank.service` to `requires`. (N, low) `properties` can emit duplicate `-o` keys and shadows `name` (`:62-72`); use an attrset. (X, low) contribution keys are unvalidated; extend the assertion (`:61-99,132-139`). (C, low) `tank/private` omits `props`, so it likely misses zstd/128K (`:49-54`). (N, info) use `lib.mergeAttrsList` (`:125`). (C, low) mountpoint directories are not explicitly created; works on the existing pool (`:61,99-102,111`). **Unresolved:** live pool properties; can a contribution extend a base dataset?
- **`modules/features/nas-vpn-client.nix`** — aspect. **Preserve:** typed settings, agenix env-file, split tunnel, NM keyfile. **Findings:** (C, medium) `autoconnect = true` + `allowed-ips = 192.168.178.0/24` can hijack a foreign LAN with the same subnet (`:38,48,56`); add `ipv4.route-metric = 1000`. (X, low) six NAS facts are duplicated across client/server/host files (`:4,47-48,57`; `nas.nix:12,26,145-147`; `wireguard-server.nix:8,12-14`); comment or share a data file. (X, low) `fwmark = 51821` has no companion `ip rule` (`:43`); drop or document. (N, low) `includes = [ secrets ]` is redundant with the global schema include (`:8`). (P, info) DNS priority sends all lookups through the tunnel; scope with `dns-search` if desired. **Unresolved:** is the server key current? Is the LAN route collision acceptable?
- **`modules/features/neovim.nix`** — aspect. **Preserve:** `wrapRc = false`, explicit plugin list, generated palette subset. **Findings:** (X, low) generated `name` is unused; colorscheme name is hardcoded (`:45`, `dots/neovim/init.lua:6`). (X, low) `variant` is not generated; `background` is hardcoded dark (`:45`, `dots/neovim/colors/oxocarbon.lua:15`). (N, info) `wrapRc = false` skips provider flags; add them if startup latency matters. **Unresolved:** is a second theme planned? Should LSP tools be user-wide?
- **`modules/features/networking-base.nix`** — aspect. **Preserve:** static default, self-registration, NetworkManager + firewall. **Findings:** (N, low) plain definitions make per-host opt-out require `mkForce`; use `lib.mkDefault` if opt-out is expected (`:6-7`). (P, info) `firewall.enable = true` restates the nixpkgs default (`:7`). **Unresolved:** is “every host must use NetworkManager/firewall” an invariant?
- **`modules/features/nix.nix`** — aspect. **Preserve:** self-registration, flakes, GC, trusted users. **Findings:** (N, low) `@wheel` trusted-users is root-equivalent through the daemon; drop or document (`:11-14`). (N, info) `"root"` is already trusted by nixpkgs (`:12`). **Unresolved:** is `@wheel` trusted-users required?
- **`modules/features/nixos-testing-vm.nix`** — aspect. **Preserve:** `vmVariant`, password override set, comments. **Findings:** (C, medium) only `miko-password` is disabled; other host secrets remain enabled and agenix activation fails without `/etc/age/host.key` (`:22-25`). Use `age.enable = lib.mkForce false;`. (X, low) `config.users.users` is the host config, not the VM config; comment (`:14-20`). (P, low) `memorySize`/`cores` should be `lib.mkDefault` (`:8-11`). (N, low) `config.age.secrets ? miko-password` assumes `age` exists (`:23`). **Unresolved:** is the NAS VM a target? Is `vm-autologin` a better fit?
- **`modules/features/obsidian.nix`** — aspect. **Preserve:** unfree battery, hjem package, vault comment. **Findings:** none substantive. (P, low) expanded `hjem` block has no content; collapse if not planned. (X, info) vault path lives only in a comment. **Unresolved:** should the vault path be documented in `docs/`?
- **`modules/features/openssh.nix`** — aspect. **Preserve:** key-only auth, no root login, self-registration. **Findings:** (N, info) `openFirewall = true` is already the nixpkgs default (`:6`). (C, low) the laptop’s sshd is exposed on every network it joins; scope if unintended (`:4-6`). (P, info) add a comment explaining why SSH is fleet-wide. **Unresolved:** is laptop SSH from untrusted networks intended? Is NAS SSH port-forwarded?
- **`modules/features/plasma.nix`** — aspect. **Preserve:** Plasma 6 setup, mime defaults, package exclusions, hjem look/shortcuts, dots files. **Findings:** (C, low) `writeShellApplication` adds `set -e`; if `plasma-apply-lookandfeel` fails, the new color/theme commands never run (`:76-83`, `plasma-apply-look.sh:1-7`). Make line 2 non-fatal or pass `bashOptions = [ ]`. (C, low latent) the removed `security.pam.services.login.fprintAuth = false` guard matters if fprintd is enabled later; restore or document. (X, low) three `kcminputrc` locations need a comment (`:10,66-69,92-95`). (P, low) mime mappings could use `lib.genAttrs` (`:21-35`). **Unresolved:** does kglobalacceld read `kglobalshortcutsrc` after the oneshot? Is the tmpfiles `r` rule permanent?
- **`modules/features/printing-scanning.nix`** — aspect. **Preserve:** `ipp-usb`, avahi, SANE, `provides.to-users` group list. **Findings:** (X, info) printing/SANE/avahi are already implied by `ipp-usb`; the `sane-airscan` backend comes from that module (`:5-14`). Add a comment or drop the redundant enables. (C, low) the old `isNormalUser` guard is gone; a future service user on a desktop host would get `lp`/`scanner` (`:17-20`). (P, info) `lp` is only for raw device access; `scanner` is useful over SSH. **Unresolved:** actual printer/scanner model; is `lp` needed?
- **`modules/features/proton-backup.nix`** — aspect. **Preserve:** restic + Proton mirror design, upload-never-delete, verification, shared `protonEnv`, heartbeat merge. **Findings:** (C, high) no mount guards on any of the three units; a missing mount can initialize an empty repo or back up an empty directory (`:129-134,147-150,156-164,175-184`). Add `AssertPathIsMountPoint`. (C, medium) `proton-drive filesystem create-folder "$parent" "$part"` may not match the pinned CLI’s `<path...>` signature; verify and use `"$parent/$part"` (`:84-86`). (C, medium) backing up live CouchDB files can hit restic’s “file changed during backup” and may omit a database file; use a ZFS snapshot (`:132-134`). (X, low) `builtins.pathExists` repeated three times; bind `enabled` (`:12,119,125`). (X, low) heartbeat ids/units repeated; derive from one table (`:14-29,148,160,177`). (D, low) heartbeat units require `status` but the aspect does not document it (`:107-110`). (C, low) upload unit lacks `network-online.target` (`:175-185`). (P, info) cache path spelled twice (`:158,164`); `cd ${repo}` unquoted (`:90`). **Unresolved:** CLI create-folder signature; is CouchDB idle at 03:00? Is the dataset intentionally created without the secret?
- **`modules/features/proton-vpn-client.nix`** — aspect. **Preserve:** typed settings, agenix env-file, full-tunnel NM profile, DNS priority. **Findings:** (C, low) rotating the secret does not restart `NetworkManager-ensure-profiles`; add `restartTriggers` keyed on the secret hash (`:32-35`). (X, low) `publicKey`/`endpoint` duplicated in both hosts; give defaults (`:6-14`). (P, info) Proton’s fixed client addresses/DNS are hardcoded; comment (`:57-65`). **Unresolved:** same server for both hosts? Is a kill switch wanted?
- **`modules/features/secrets.nix`** — aspect. **Preserve:** agenix import, CLI + age, `/etc/age/host.key`, self-registration. **Findings:** (D, info) explicit `secrets` includes elsewhere are redundant with the schema default (`:22`). (N, info) `pkgs.age` is for interactive use; comment. (N, low) `age.identityPaths` could be `lib.mkDefault` if hosts may append/replace (`:15`). (N, low) no tmpfiles rule pins `host.key` mode (`:17-19`). **Unresolved:** should secrets be a default include? Is `pkgs.age` used on the NAS? Will identity paths differ?
- **`modules/features/seerr.nix`** — aspect. **Preserve:** feature shape, fixed user, storage oneshot, bind mount, assert. **Findings:** (X, low) `StateDirectory = "seerr"` still creates `/var/lib/seerr` on the root dataset before the bind mount hides it (`:52`; nixpkgs module). Comment or force `StateDirectory = [ ]`. (N, low) `stateRevision = 1` is the invariant that makes the bind target correct; comment (`:24,52`). (X, low) storage oneshot pattern duplicated; keep unless it grows. **Unresolved:** pin UID/GID for dataset-backed users? Does Seerr support a bind-address variable?
- **`modules/features/service-names.nix`** — aspect. **Preserve:** private-by-default guard, DNS-01, Caddy plugin pin, unique-hostname assertion. **Findings:** (C, high) Caddy admin API is enabled by default and unauthenticated on localhost while the config holds a zone-wide Cloudflare token (`:72-83`). Disable admin or restrict it. (X, medium) `internalRanges` is a third copy of the network topology and is IPv4-only (`:7-12`); add a setting or derive from WireGuard/LAN. (N, medium) manual TCP 80/443 omits UDP 443/HTTP3 and does not follow `services.caddy` ports (`:85-88`); use `openFirewall = true` or document. (C, low) shape assertion runs after `attrNames`/`//`, so malformed entries produce cryptic errors (`:32-33,60-68`); validate before merging. (X, low) `domain` is only the ACME email but looks like the service domain (`:4,74`). (X, low) route merge/public filter duplicated with `ddns`/`status` (`:32-33`). (N, low) secret owner hardcodes `"caddy"`; use `config.services.caddy.user` (`:55-58`). **Unresolved:** is local service compromise in scope? Is LAN IPv6 used? Is HTTP/3 intentionally disabled?
- **`modules/features/servarr.nix`** — aspect. **Preserve:** one aspect for the trio, quirk contributions, bind mounts, storage oneshots, hardening. **Findings:** (C, medium) prowlarr’s UID/GID are not pinned even though its state is on the dataset (`:56-60,79`); a reinstall can orphan ownership. Pin `uid`/`gid`. (N, low) `User`/`Group` should be `lib.mkDefault`; upstream already defines them, and a host override would currently conflict (`:74-76`). (X, low) prowlarr is excluded from `ProtectSystem`/`ReadWritePaths` without explanation (`:81-87`). (P, low) UMask comment points at the wrong mechanism; cross-service access comes from media-storage ACLs (`:77-78`). (X, low) app metadata spread across four lists; one table would reduce maintenance (`:65,89,93-99,81`). **Unresolved:** do supplementary groups survive `PrivateUsers`? Is the prowlarr hardening exclusion deliberate?
- **`modules/features/status.nix`** — aspect. **Preserve:** suite partitioning, `always-run`, DDNS public-IP suite, fixed gatus user, heartbeat token/unit wiring. **Findings:** (D, medium) DDNS names are recomputed from duplicated route logic and `host.settings.ddns.extraNames` without including `ddns` (`:53-55`); move DDNS checks into `ddns` or include it. (C, low) duplicate names in `extraNames` + public routes produce duplicate Gatus endpoints; use `lib.unique` (`:55`). (C, low) `slug` omits Gatus’s trim step (`:28`). (C, low) heartbeat ids are interpolated into shell `case` patterns and systemd instance names without validation (`:107-113,226-232`); add an assertion. (P, low) `status-heartbeat@` runs as root; it only needs the gatus-readable token (`:226-233`). **Unresolved:** how does `status.sk4rd.com` resolve internally? Is status NAS-only?
- **`modules/features/systemd-boot.nix`** — aspect. **Preserve:** self-registration, editor off, generation limit, EFI variables. **Findings:** (N, low) mixed nesting under `boot.loader`; nest `systemd-boot` options (`:5-10`). (X, low) implicit ESP-at-`/boot` assumption; comment (`:9`). (P, info) comment why `editor = false` and `configurationLimit = 10`. **Unresolved:** is 10 a deliberate ESP budget?
- **`modules/features/vesktop.nix`** — aspect. **Preserve:** token mapping, selector strategy, clobber, correct path. **Findings:** (C, low) interactive text default/hover/active are all very light; hover/selection affordance is weak (`:35-37`). (P, low) several distinct theme steps are flattened to one color (`:26-27,41-47`). (C, low) legacy Discord tokens are not mapped; some surfaces may keep stock colors (`:13-60`). (P, low) `.theme-light` is not matched; light Discord gets no theme (`:9`). (N, info) `quickCss` references `vars` before definition; use `concatMapAttrsStringSep` (`:8-13`). (X, info) in-app QuickCSS edits are overwritten; comment (`:67-70`). **Unresolved:** is Vesktop on the NAS intended? Is QuickCSS actually loaded on a fresh profile?
- **`modules/features/voxtype.nix`** — aspect. **Preserve:** uinput rationale, pinned model, TOML config, KDE shortcut, user service. **Findings:** (C, low) `initial_prompt` spans two lines, so the TOML value contains a newline and 12 spaces (`:27-28`); keep it one line. **Unresolved:** was the multiline prompt intentional?
- **`modules/features/wireguard-server.nix`** — aspect. **Preserve:** typed settings, agenix key, restart trigger, NAT, trusted interface comment. **Findings:** (P, info) `trustedInterfaces = [ "wg0" ]` gives peers full access to NAS/LAN; documented tradeoff (`:52-56`). (X, low) `restartTriggers` assumes the script backend, not `useNetworkd` (`:58-61`); comment or assert. (N, low) `peers = map …` is a second schema; `peers = cfg.peers;` is equivalent (`:49`). (N, info) `ip_forward` is already set by `networking.nat` (`:70`). (D, low) no `secrets` include; relies on global default (`:43,48`). (X, low) VPN subnet/port duplicated in client/Caddy (`:8,14`; `nas-vpn-client.nix:47-48`; `service-names.nix:11`). **Unresolved:** is key rotation documented? Is the `10.100.0.4` peer current?
- **`modules/features/yubikey.nix`** — aspect. **Preserve:** host pcscd/gpg setup, per-serial identities, fish wrapper, scdaemon config. **Findings:** (C, medium) `pinentryPackage = pkgs.pinentry-qt` is applied to the headless NAS too; use the desktop default or curses on NAS (`:17`). (N, low) `services.pcscd`/udev/ykman can be replaced by `programs.yubikey-manager.enable` (`:12,30-32,36`). (X, low) identity strings repeated three times; derive from a serial→identity attrset (`:46-57`). (C, low) with two keys inserted, the wrapper picks the first serial even if it is not a recipient (`:70-75`); warn or require one key. (P, info) comment why `disable-ccid` is needed (`:85-89`). (P, info) comment why identity files are `copy`/600 (`:4-8`). **Unresolved:** is agenix run outside fish? Does hjem create `.gnupg` with 700?
- **`modules/features/zoxide.nix`** — aspect. **Preserve:** static self-registration, NixOS module. **Findings:** none. **Unresolved:** should zoxide be host-global even on a host without an interactive user?
- **`modules/features/zram.nix`** — aspect. **Preserve:** static self-registration, nixpkgs defaults. **Findings:** none. **Unresolved:** is zram the only swap intended? Tune `memoryPercent` per host?

### Secrets

- **`secrets/agenix-rules.nix`** — data/config. **Preserve:** named recipients, least-privilege per secret, YubiKey serial comments, correct agenix rules filename. **Findings:** (X, medium) `miko-password.age` lists all hosts, and `modules/users/miko.nix:37` provides it to every host; adding a host silently requires adding a recipient here (`:12-18`). Add a comment. (X, low) the two YubiKeys are repeated in every entry; bind `yubikeys` once (`:13-14` etc.). (C, info) `agenix -c` cannot check non-SSH recipients, so this file cannot be CI-verified; document the limitation. **Unresolved:** are the two Proton env files the same private key? Should `miko-password` be on every host?

---

## 8. What not to change

- Do not replace the flake’s `evalModules`/`import-tree` shape with a hand-maintained import list.
- Do not rewrite `lib/settings-type.nix`; it matches the pinned Den pattern. Add comments, not machinery.
- Do not convert every feature into a policy/quirk/provider. The simple one-purpose aspects (`gh`, `zoxide`, `zram`, `bluetooth`, `audio`) are already the right size.
- Do not split `media-downloads.nix` or `status.nix` merely to reduce line count; their complexity is mostly essential. Split only along a real concern boundary if a second consumer appears.
- Do not churn the theme into a generic theming framework. The single-palette design is clear and works.
- Do not move plain files out of `dots/`; the “plain files stay plain” rule is a strength.
- Do not add `den.policies` everywhere. The current `provides`/quirk usage is understandable; migrate only where it removes a real hidden dependency or duplication.
