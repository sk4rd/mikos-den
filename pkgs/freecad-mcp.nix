{ fetchFromGitHub, python3Packages }:

python3Packages.buildPythonApplication rec {
  pname = "freecad-mcp";
  version = "0.1.32";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "neka-nat";
    repo = "freecad-mcp";
    tag = "v${version}";
    hash = "sha256-4BYPLCgQ6As1ceC5MUkfz5O8Lm+TbnSqiFZ8ffqD2uc=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies =
    with python3Packages;
    [
      anyio
      certifi
      mcp
      pyjwt
      pydantic
      validators
    ]
    ++ mcp.optional-dependencies.cli;

  nativeCheckInputs = [ python3Packages.pytestCheckHook ];
  # Both start a bare Python subprocess, which cannot import the dependencies from the build environment.
  disabledTests = [
    "test_headless_cannot_read_the_open_mcp_stdin"
    "test_stdio_client_receives_error_flags_and_original_content"
  ];

  # The server talks to this addon over RPC, so the two are pinned together. It goes into FreeCAD's Mod folder.
  postInstall = ''
    mkdir -p $out/share/freecad-mcp
    cp -r addon/FreeCADMCP $out/share/freecad-mcp/
  '';

  meta.mainProgram = "freecad-mcp";
}
