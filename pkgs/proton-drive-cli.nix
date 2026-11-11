{ proton-drive-cli }:

# Upstream pins one exact Bun release and refuses any other, which breaks the
# build whenever nixpkgs moves Bun on. Any newer 1.x works.
proton-drive-cli.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    substituteInPlace package.json --replace-fail '"bun": "1.4.2"' '"bun": ">=1.4.2"'
  '';
})
