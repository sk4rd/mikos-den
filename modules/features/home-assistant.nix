{ ... }:
let
  stateDir = "/var/lib/hass";
  dataset = "tank/services/home-assistant";

  # Home Assistant pins aioipp==0.19.3 for the ipp integration, but nixpkgs only
  # ships pyipp 0.17.2. Without 0.19.3 the requirement check fails and the
  # printer integration refuses to load.
  mkAioipp =
    pkgs: ps:
    ps.buildPythonPackage rec {
      pname = "aioipp";
      version = "0.19.3";
      format = "pyproject";

      src = pkgs.fetchPypi {
        inherit pname version;
        hash = "sha256-/TjW2dpRDlqcoE1Je8vgnqt6qYdY5qgVk/PkHJuah4s=";
      };

      nativeBuildInputs = [ ps.poetry-core ];
      propagatedBuildInputs = with ps; [
        aiohttp
        awesomeversion
        deepmerge
        yarl
      ];

      doCheck = false;
      pythonImportsCheck = [ "pyipp" ];
    };
in
{
  den.aspects.home-assistant.nixos =
    { lib, pkgs, ... }:
    {
      services.home-assistant = {
        enable = true;
        configDir = stateDir;

        # default_config only. Anything else has to be listed here, otherwise
        # the integration is not registered and its config flow fails with
        # "Invalid handler specified".
        extraComponents = [
          "fritz" # FRITZ!Box Tools: presence trackers for LAN/WiFi devices
          "google_translate" # onboarding TTS choice; needs the gtts module
          "ipp" # Lexmark MC3224adwe
          "samsungtv" # Samsung S95BA
          "zha" # SLZB-06M Zigbee coordinator
        ];

        # nixpkgs' component->requirement map is incomplete for 2026.10.2, so
        # the python modules of a few default_config integrations have to be
        # pulled in by hand. These land in the store and Home Assistant skips
        # pip, so it only needs the modules to be importable at all: a
        # default_config dependency that cannot be imported takes the whole
        # bundle (and with it ssdp/zeroconf discovery) down.
        extraPackages = ps: [
          (mkAioipp pkgs ps) # ipp
          ps.aiodhcpwatcher # dhcp
          ps.aiodiscover # dhcp
          ps.cached-ipaddress # dhcp
          ps.av # stream
          ps.go2rtc-client # go2rtc
          ps.pymetno # met
          ps.pyturbojpeg # stream
        ];
      };

      fileSystems.${stateDir} = {
        device = dataset;
        fsType = "zfs";
        # Do not add this mount to local-fs.target. The dataset is created by
        # zfs-datasets.service at multi-user; a boot-time mount attempt would
        # fail first and drop the system into emergency mode. Home Assistant's
        # RequiresMountsFor starts the mount after dataset reconciliation.
        options = [ "zfsutil" "noauto" ];
      };

      users.users.hass.createHome = lib.mkForce false;

      systemd.services.home-assistant = {
        after = [ "zfs-datasets.service" ];
        requires = [ "zfs-datasets.service" ];

        unitConfig = {
          RequiresMountsFor = stateDir;
          AssertPathIsMountPoint = stateDir;
        };
      };

      networking.firewall.allowedTCPPorts = [ 8123 ];
    };
}
