{ config, lib, ... }:

let
  inherit (config) theme;
  c = theme.colors;
  a = theme.ansiNamed;

  palette = {
    primary = c.accent;
    on_primary = c.bg;
    secondary = c.accentAlt;
    on_secondary = c.bg;
    tertiary = c.teal;
    on_tertiary = c.bg;
    error = c.error;
    on_error = c.bg;
    surface = c.bg;
    on_surface = c.fg;
    surface_variant = c.surface;
    on_surface_variant = c.subtle;
    outline = c.muted;
    shadow = c.bgDim;
    hover = c.overlay;
    on_hover = c.fgBright;
  };

  ansiNames = [
    "black"
    "red"
    "green"
    "yellow"
    "blue"
    "magenta"
    "cyan"
    "white"
  ];

  shellPalette = {
    dark = lib.mapAttrs' (name: lib.nameValuePair (lib.toCamelCase name)) palette // {
      terminal = {
        background = c.bg;
        foreground = c.fg;
        cursor = c.cursor;
        cursorText = c.cursorText;
        selectionBg = c.selection;
        selectionFg = c.fg;
        normal = lib.getAttrs ansiNames a;
        bright = lib.genAttrs ansiNames (n: a."bright${lib.toSentenceCase n}");
      };
    };
  };

  cursor = {
    theme = "Bibata-Modern-Ice";
    size = 24;
  };
  cursorPackage = pkgs: pkgs.bibata-cursors;

  appearance = {
    font_family = theme.fonts.ui.name;
    corner_radius_scale = 1.25;
  };

  groupStyle = {
    border = "outline_variant";
    opacity = 0.85;
    padding = 10.0;
  };
  capsuleStyle = lib.mapAttrs' (n: lib.nameValuePair "capsule_${n}") groupStyle;

  wallpaperFor = pkgs: import ../../lib/theme/render/wallpaper.nix { inherit pkgs lib theme; };

  # The icon font has only an outline skull, so the kill switch button swaps two SVGs: an
  # accent outline when off and a filled one in the theme red when on. Both share one head
  # outline; the filled one cuts the eyes and teeth out of it.
  skullSvg =
    filled:
    let
      head = "M12 4c4.418 0 8 3.358 8 7.5c0 1.901-.755 3.637-2 4.96V19a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1v-2.54C4.755 15.137 4 13.401 4 11.5C4 7.358 7.582 4 12 4z";
      body =
        if filled then
          ''<path fill="${c.error}" fill-rule="evenodd" d="${head}M9 9.5a1.75 1.75 0 1 0 0 3.5a1.75 1.75 0 1 0 0-3.5zM15 9.5a1.75 1.75 0 1 0 0 3.5a1.75 1.75 0 1 0 0-3.5zM9.6 16.5h.8v2.5h-.8zM13.6 16.5h.8v2.5h-.8z"/>''
        else
          ''<g fill="none" stroke="${c.accent}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="${head}"/><circle cx="9" cy="11.25" r="1"/><circle cx="15" cy="11.25" r="1"/><path d="M10 16.5V20M14 16.5V20"/></g>'';
    in
    ''<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">${body}</svg>'';

  # A path source: a directory holding one directory per plugin.
  pluginsFor =
    pkgs:
    pkgs.linkFarm "noctalia-plugins" [
      {
        name = "claude/plugin.toml";
        path = ../../dots/noctalia/claude/plugin.toml;
      }
      {
        name = "claude/usage.luau";
        path = ../../dots/noctalia/claude/usage.luau;
      }
      {
        name = "vpn/plugin.toml";
        path = ../../dots/noctalia/vpn/plugin.toml;
      }
      {
        name = "vpn/vpn.luau";
        path = ../../dots/noctalia/vpn/vpn.luau;
      }
      {
        name = "vpn/killswitch.luau";
        path = ../../dots/noctalia/vpn/killswitch.luau;
      }
      {
        name = "vpn/skull.svg";
        path = pkgs.writeText "skull.svg" (skullSvg false);
      }
      {
        name = "vpn/skull-filled.svg";
        path = pkgs.writeText "skull-filled.svg" (skullSvg true);
      }
    ];
in
{
  den.aspects.noctalia = {
    settings.idleSuspendSeconds = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Seconds idle before locking and suspending, or null to never suspend when idle";
    };

    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        xkb = config.services.xserver.xkb;
        uiFont = "${theme.fonts.ui.name} ${toString theme.fonts.ui.size}";
      in
      {
        programs.umbriel.enable = true;
        programs.noctalia = {
          enable = true;
          recommendedServices.enable = true;
        };

        services.displayManager.noctalia-greeter = {
          enable = true;
          cursorTheme = {
            package = cursorPackage pkgs;
            name = cursor.theme;
          };
          settings = {
            session.default = "Umbriel";
            user.default = lib.head (lib.attrNames host.users);
            keyboard = {
              inherit (xkb) layout variant;
            };
            cursor.size = cursor.size;
            appearance = appearance // {
              scheme = "Synced";
              theme_mode = theme.variant;
              scheme_selector_position = "hidden";
              inherit palette;
              wallpaper = {
                path = "${wallpaperFor pkgs}";
                fill_mode = "crop";
                fill_color = c.bg;
              };
            };
          };
        };

        # Noctalia keeps its clipboard and notification history encrypted with a key
        # from the Secret Service, and a bare compositor session doesn't provide one.
        services.gnome.gnome-keyring.enable = true;

        environment.sessionVariables.NIXOS_OZONE_WL = "1";

        # Umbriel's lid_close event suspends instead (see the hjem half), because logind
        # can't tell Noctalia's caffeine apart: it only holds an `idle` inhibitor, which
        # logind never consults for the lid switch.
        services.logind.settings.Login = {
          HandleLidSwitch = "ignore";
          HandleLidSwitchExternalPower = "ignore";
          HandleLidSwitchDocked = "ignore";
        };

        # The greeter looks for sessions under the system profile, which leaves this
        # directory out unless asked; without it the login screen has no Umbriel to offer.
        environment.pathsToLink = [ "/share/wayland-sessions" ];

        environment.systemPackages = [
          pkgs.adw-gtk3
          pkgs.adwaita-icon-theme
          (cursorPackage pkgs)
          pkgs.papirus-icon-theme
        ];

        qt = {
          enable = true;
          platformTheme = "kde";
        };

        programs.dconf.profiles.user.databases = [
          {
            locks = map (key: "/org/gnome/desktop/interface/${key}") [
              "icon-theme"
              "font-name"
              "document-font-name"
              "monospace-font-name"
            ];

            settings."org/gnome/desktop/interface" = {
              font-name = uiFont;
              document-font-name = uiFont;
              monospace-font-name = "${theme.fonts.mono.name} ${toString theme.fonts.mono.size}";
              gtk-theme = "adw-gtk3-${theme.variant}";
              icon-theme = "Papirus-${lib.toSentenceCase theme.variant}";
              cursor-theme = cursor.theme;
              cursor-size = lib.gvariant.mkInt32 cursor.size;
              color-scheme = "prefer-${theme.variant}";
            };
          }
        ];
      };

    hjem =
      {
        config,
        host,
        osConfig,
        pkgs,
        ...
      }:
      let
        toml = pkgs.formats.toml { };
        suspendAfter = host.settings.noctalia.idleSuspendSeconds;

        rawShellConfig = toml.generate "noctalia-config.toml" {
          shell = appearance // {
            polkit_agent = true;
            setup_wizard_enabled = false;
            animation.speed = 1.25;
            # Orphan adoption can re-offer stale content during clipboard handoffs.
            clipboard_keep_from_closed_apps = false;
            panel = {
              transparency_mode = "soft";
              control_center_placement = "floating";
              wallpaper_placement = "floating";
              session_placement = "floating";
            };
          };

          bar.default = capsuleStyle // {
            background_opacity = 0.0;
            shadow = false;
            thickness = 38;
            margin_edge = 8;
            margin_ends = 12;
            widget_spacing = 8;
            concave_edge_corners = false;
            capsule = true;
            icon_color = "primary";
            start = [ "group:navigation" ];
            center = [ "clock" ];
            end = [
              "group:system"
              "group:connectivity"
              "group:levels"
              "group:power"
            ];

            capsule_group = lib.mapAttrsToList (id: members: groupStyle // { inherit id members; }) {
              navigation = [
                "launcher"
                "workspaces"
              ];
              system = [
                "media"
                "tray"
                "notifications"
                "clipboard"
              ];
              connectivity = [
                "network"
                "bluetooth"
                "proton-vpn"
                "vpn-killswitch"
              ];
              levels = [
                "claude-usage"
                "volume"
                "brightness"
                "battery"
              ];
              power = [
                "caffeine"
                "control-center"
                "session"
              ];
            };
          };

          widget = {
            workspaces = {
              occupied_color = "secondary";
              empty_color = "outline_variant";
            };
            # Both come from the proton-vpn-client aspect: the connection, and
            # proton-killswitch.service.
            proton-vpn.type = "miko/vpn:vpn";
            vpn-killswitch.type = "miko/vpn:killswitch";
            # Fed by the status line command of the ai aspect; hidden until that has run.
            claude-usage.type = "miko/claude:usage";
            clock.format = "{:%a %d %b  %H:%M}";
            media = {
              hide_when_no_media = true;
              hide_when_idle = true;
            };
          };

          wallpaper.default.path = "${wallpaperFor pkgs}";

          plugins = {
            enabled = [
              "miko/claude"
              "miko/vpn"
            ];
            source = [
              {
                name = "miko";
                kind = "path";
                location = "${pluginsFor pkgs}";
                enabled = true;
              }
            ];
          };

          theme = {
            mode = theme.variant;
            source = "custom";
            custom_palette = theme.name;
            templates.builtin_ids = [
              "umbriel"
              "gtk3"
              "gtk4"
              "kcolorscheme"
            ];
          };

          idle = {
            behavior_order = [
              "lock"
              "screen-off"
            ]
            ++ lib.optional (suspendAfter != null) "suspend";

            behavior = {
              lock = {
                timeout = 600;
                action = "lock";
                enabled = true;
              };
              screen-off = {
                timeout = 660;
                action = "screen_off";
                enabled = true;
              };
            }
            // lib.optionalAttrs (suspendAfter != null) {
              suspend = {
                timeout = suspendAfter;
                action = "lock_and_suspend";
                enabled = true;
              };
            };
          };
        };

        shellConfig = pkgs.runCommand "noctalia-config" { } ''
          export HOME=$TMPDIR
          ${lib.getExe pkgs.noctalia} config validate ${rawShellConfig}
          cp ${rawShellConfig} $out
        '';

        xkb = osConfig.services.xserver.xkb;

        fragments = lib.filter (lib.hasPrefix ".config/umbriel/conf.d/") (lib.attrNames config.files);

        lidClose = pkgs.writeShellScript "lid-close" ''
          # Caffeine is visible to logind as a blocking idle inhibitor held by noctalia.
          if ${pkgs.systemd}/bin/systemd-inhibit --list --no-legend \
            | ${pkgs.gnugrep}/bin/grep -Eq '^noctalia\s.*\sidle\s+Caffeine\s+block'; then
            exit 0
          fi
          exec ${pkgs.systemd}/bin/systemctl suspend
        '';
      in
      {
        files.".config/noctalia/config.toml".source = shellConfig;
        files.".config/noctalia/palettes/${theme.name}.json".source =
          (pkgs.formats.json { }).generate "${theme.name}-palette.json"
            shellPalette;

        files.".config/umbriel/config.toml".source = ../../dots/umbriel/config.toml;
        files.".config/umbriel/nix.toml".source = toml.generate "umbriel-nix.toml" {
          # Other aspects and hosts drop their fragments into conf.d; Umbriel has no glob
          # includes, so the list is built from the files hjem is about to install.
          include.optional.files = map (f: "~/${f}") fragments;
          input.keyboard = {
            inherit (xkb) layout variant;
          };
          input.cursor = cursor;
          events.lid_close = "${lidClose}";
        };
      };
  };
}
