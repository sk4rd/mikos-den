{ lib, ... }:

let
  mimeFor =
    prefix: types: app:
    lib.genAttrs (map (t: "${prefix}/${t}") types) (_: app);
in
{
  den.aspects.viewers = {
    nixos =
      { pkgs, ... }:
      {
        # Gwenview and Okular draw their toolbar icons from Breeze.
        environment.systemPackages = [ pkgs.kdePackages.breeze-icons ];

        xdg.mime.defaultApplications =
          mimeFor "image" [
            "avif"
            "bmp"
            "gif"
            "jpeg"
            "png"
            "svg+xml"
            "tiff"
            "webp"
          ] "org.kde.gwenview.desktop"
          // mimeFor "video" [
            "mp4"
            "mpeg"
            "quicktime"
            "webm"
            "x-matroska"
            "x-msvideo"
          ] "org.kde.haruna.desktop"
          // {
            "application/pdf" = "okularApplication_pdf.desktop";
          };
      };

    hjem =
      { pkgs, ... }:
      {
        packages = [
          pkgs.kdePackages.gwenview
          pkgs.haruna
          pkgs.kdePackages.okular
        ];
      };
  };
}
