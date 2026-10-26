{ den, ... }:

{
  den.aspects.viewers = {
    hjem = { pkgs, ... }: {
      packages = [
        pkgs.imv
        pkgs.kdePackages.okular
        pkgs.mpv
      ];
    };

    nixos.xdg.mime.defaultApplications = {
      "application/pdf" = "okularApplication_pdf.desktop";

      "image/avif" = "imv.desktop";
      "image/bmp" = "imv.desktop";
      "image/gif" = "imv.desktop";
      "image/jpeg" = "imv.desktop";
      "image/png" = "imv.desktop";
      "image/svg+xml" = "imv.desktop";
      "image/tiff" = "imv.desktop";
      "image/webp" = "imv.desktop";

      "video/mp4" = "mpv.desktop";
      "video/mpeg" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
    };
  };
}
