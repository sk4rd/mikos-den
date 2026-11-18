{
  appimageTools,
  fetchurl,
  python3,
  runCommand,
}:

let
  pname = "nimbalyst";
  version = "0.83.0";
  src = fetchurl {
    url = "https://github.com/nimbalyst/nimbalyst/releases/download/v${version}/Nimbalyst-Linux.AppImage";
    hash = "sha256-j1YU0CFfjir3YcBPgbCYRU+ItxEQRmeVN9Q6X+US3C8=";
  };
  contents = appimageTools.extract { inherit pname version src; };
  # A full copy rather than a symlink tree: Electron finds its resources from its resolved path,
  # and the tutorial copies symlinks as symlinks.
  patched = runCommand "${pname}-${version}-patched" { nativeBuildInputs = [ python3 ]; } ''
    cp -r ${contents} $out
    chmod -R u+w $out
    python3 ${./patch-tutorial.py} ${contents}/resources/app.asar $out/resources/app.asar
  '';
in
appimageTools.wrapAppImage {
  inherit pname version;
  src = patched;
  extraInstallCommands = ''
    install -Dm444 ${contents}/nimbalyst.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/nimbalyst.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=nimbalyst'
    cp -r ${contents}/usr/share/icons $out/share/icons
  '';
}
