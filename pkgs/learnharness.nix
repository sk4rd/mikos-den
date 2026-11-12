{ appimageTools, fetchurl }:

let
  pname = "learnharness";
  version = "0.6.1";
  src = fetchurl {
    url = "https://github.com/amosblomqvist/learnharness/releases/download/v${version}/LearnHarness-${version}-x86_64.AppImage";
    hash = "sha256-uKAz63QhZ3iT2W5JiLMBU/3+T8bw3EVveUcWG7oEG5g=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;
  extraInstallCommands = ''
    install -Dm444 ${contents}/learnharness.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/learnharness.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=learnharness'
    cp -r ${contents}/usr/share/icons $out/share/icons
  '';
}
