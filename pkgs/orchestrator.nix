{
  lib,
  appimageTools,
  fetchurl,
  glibc,
  patchelf,
  makeWrapper,
  git,
  gh,
  tmux,
}:

let
  pname = "orchestrator";
  version = "0.14.10";
  src = fetchurl {
    url = "https://github.com/OrchestratorInc/agent-orchestrator/releases/download/v${version}/agent-orchestrator-linux-x64.AppImage";
    hash = "sha256-QlNIiq37ddvPzNS4Lh57sSY0giDtwy1qKULQSQyLIP8=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # The app-owned daemon calls these tools for worktrees and GitHub operations.
  extraPkgs = _: [
    git
    gh
    tmux
  ];

  extraInstallCommands = ''
    source ${makeWrapper}/nix-support/setup-hook
    install -Dm444 ${contents}/*.desktop -t $out/share/applications
    substituteInPlace $out/share/applications/*.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=orchestrator'
    cp -r ${contents}/usr/share/icons $out/share/icons

    # Expose the matching CLI without relying on nix-ld or the frozen npm client.
    install -Dm755 ${contents}/resources/daemon/ao $out/libexec/ao
    ${patchelf}/bin/patchelf \
      --set-interpreter ${glibc}/lib/ld-linux-x86-64.so.2 \
      --set-rpath ${lib.makeLibraryPath [ glibc ]} \
      $out/libexec/ao
    makeWrapper $out/libexec/ao $out/bin/ao \
      --suffix PATH : ${
        lib.makeBinPath [
          git
          gh
          tmux
        ]
      }
  '';

  meta = {
    description = "Desktop workspace for coordinating coding agents in isolated Git worktrees";
    homepage = "https://orchestrator.inc/";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "orchestrator";
  };
}
