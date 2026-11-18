{ appimageTools, fetchurl }:

let
  pname = "nimbalyst";
  version = "0.83.0";
  src = fetchurl {
    url = "https://github.com/nimbalyst/nimbalyst/releases/download/v${version}/Nimbalyst-Linux.AppImage";
    hash = "sha256-j1YU0CFfjir3YcBPgbCYRU+ItxEQRmeVN9Q6X+US3C8=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    install -Dm444 ${contents}/nimbalyst.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/nimbalyst.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=nimbalyst'
    cp -r ${contents}/usr/share/icons $out/share/icons
  '';
}
