{ den, ... }:
let
  serviceName = "home-assistant";
  stateDir = "/var/lib/hass";
  dataset = "tank/services/${serviceName}";

  # HA pins aioipp 0.19.3, nixpkgs ships 0.17.2; without it the printer integration refuses to load.
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
  den.aspects.home-assistant = {
    includes = [ den.aspects.nas-storage ];

    service-routes = {
      "ha.sk4rd.com" = {
        proxy = "reverse_proxy 127.0.0.1:8123";
      };
    };

    status-endpoints = [
      {
        name = "Home Assistant";
        group = "Home";
        url = "http://127.0.0.1:8123/";
        conditions = [ "[STATUS] == 200" ];
      }
    ];

    storage-datasets = {
      "services/${serviceName}" = {
        mountpoint = "/var/lib/hass";
        owner = "hass";
        group = "hass";
        mode = "0750";
        props = {
          recordsize = "128K";
          compression = "zstd";
        };
      };
    };

    nixos =
      { lib, pkgs, ... }:
      {
        services.home-assistant = {
          enable = true;
          configDir = stateDir;
          config = { };

          extraComponents = [
            "fritz"
            "google_translate" # onboarding's TTS choice
            "ipp"
            "samsungtv"
            "zha"
          ];

          # nixpkgs' requirement map misses some default_config deps; one that cannot import
          # takes the whole bundle (and ssdp/zeroconf discovery) down.
          extraPackages = ps: [
            (mkAioipp pkgs ps)
            ps.aiodhcpwatcher # dhcp
            ps.aiodiscover # dhcp
            ps.cached-ipaddress # dhcp
            ps.av # stream
            ps.go2rtc-client
            ps.pymetno # met
            ps.pyturbojpeg # stream
          ];
        };

        fileSystems.${stateDir} = {
          device = dataset;
          fsType = "zfs";
          # noauto: zfs-datasets creates it at multi-user; a boot mount would hit emergency mode.
          options = [
            "zfsutil"
            "noauto"
          ];
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
  };
}
