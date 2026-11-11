{
  lib,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  makeWrapper,
  bubblewrap,
  ripgrep,
  wl-clipboard,
}:

buildGoModule rec {
  pname = "reasonix";
  version = "2.59.0";

  src = fetchFromGitHub {
    owner = "esengine";
    repo = "DeepSeek-Reasonix";
    tag = "v${version}";
    hash = "sha256-uWzz171xu1rax+Gm11bCZ3VoHdaLkH8vU714TpxYwFI=";
  };

  # Mistral streams delta.content as an array of parts, which upstream cannot decode.
  patches = [ ./mistral-content-parts.patch ];

  vendorHash = "sha256-7i49Vp8aTC23Ak0Oc3oO++ygxxUkczBIOBs6/fSVSNQ=";

  subPackages = [ "cmd/reasonix" ];
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
    "-X main.version=v${version}"
    "-X reasonix/internal/tools/productdocs.linkedVersion=v${version}"
  ];

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];

  # bwrap is what confines its bash tool, and it is looked up on PATH at run time.
  # wl-copy/wl-paste are the clipboard it shells out to on Wayland, also looked up
  # on PATH at startup, so /copy and Ctrl+V fail without them.
  postInstall = ''
    installShellCompletion --cmd reasonix \
      --bash <($out/bin/reasonix completion bash) \
      --fish <($out/bin/reasonix completion fish) \
      --zsh <($out/bin/reasonix completion zsh)

    wrapProgram $out/bin/reasonix \
      --suffix PATH : ${
        lib.makeBinPath [
          bubblewrap
          ripgrep
          wl-clipboard
        ]
      }
  '';
}
