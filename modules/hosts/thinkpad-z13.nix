{ den, ... }:

{
  den.hosts.x86_64-linux.thinkpad-z13 = { };

  den.aspects.thinkpad-z13 = {
    includes = [ den.aspects.disko ];
    nixos = {
      system.stateVersion = "26.11"; # No need to change this line

      # Manage disk with disko
      disko.devices.disk.main = {
        device = "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b444a481737ed";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                extraArgs = [
                  "-F"
                  "32"
                ];
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };
            cryptroot = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                extraFormatArgs = [ "--type=luks2" ];
                settings.allowDiscards = true;
                content = {
                  type = "filesystem";
                  format = "ext4";
                  mountpoint = "/";
                  mountOptions = [ "noatime" ];
                };
              };
            };
          };
        };
      };
    };
  };
}
