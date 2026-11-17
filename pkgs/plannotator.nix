{
  autoPatchelfHook,
  fetchFromGitHub,
  fetchurl,
  makeBinaryWrapper,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "plannotator";
  version = "0.28.67";

  src = fetchurl {
    url = "https://github.com/backnotprop/plannotator/releases/download/v${finalAttrs.version}/plannotator-linux-x64.tar.xz";
    hash = "sha256-d9NbaC7LjsyFoc57jUNbjrS+fiddnmbjnV0N6gxi1ro=";
  };
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
  ];
  # A Bun executable carries the app inside itself, and strip would cut it off.
  dontStrip = true;

  # Nix owns the version, so the binary's own update check would only nag.
  installPhase = ''
    install -Dm755 plannotator-linux-x64 $out/libexec/plannotator
    makeBinaryWrapper $out/libexec/plannotator $out/bin/plannotator \
      --set PLANNOTATOR_UPDATE_CHECK 0 \
      --set NO_ANON_PING 1
  '';

  passthru.plugin = fetchFromGitHub {
    owner = "backnotprop";
    repo = "plannotator";
    tag = "v${finalAttrs.version}";
    hash = "sha256-JCbXHKUMi27eVg2jUkoGTjE+ZGLPGL9SzaOjHkppzcc=";
  };

  meta.mainProgram = "plannotator";
})
