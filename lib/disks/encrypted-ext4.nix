# Create a fat32 boot parition with luks encrypted ext4 root
# Pass the device disk-id
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
