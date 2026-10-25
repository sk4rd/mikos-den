# FAT32 ESP + LUKS2 ext4 root; takes the disk id.
device: {
  inherit device;
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
}
