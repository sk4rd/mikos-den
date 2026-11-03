{ config, ... }:

let
  inherit (config) theme;
in
{
  den.aspects.neovim = {
    hjem =
      {
        pkgs,
        lib,
        ...
      }:
      let
        mermaid-nvim = pkgs.vimUtils.buildVimPlugin {
          pname = "mermaid.nvim";
          version = "unstable-2026-09-15";
          src = pkgs.fetchFromGitHub {
            owner = "kevalin";
            repo = "mermaid.nvim";
            rev = "4da12693b3b4d63b67d07bafe8340b4abc265c70";
            hash = "sha256-SRg1V6fNlv+4Vrf1+mTNogIT/8X9DEl53+OhXm6crG8=";
          };
        };
      in
      {
        packages = [
          pkgs.ripgrep
          pkgs.nixd
          pkgs.nixfmt
          pkgs.lua-language-server
          (pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
            # Keep init.lua as the rc file (wrapRc = false).
            wrapRc = false;
            plugins = with pkgs.vimPlugins; [
              lualine-nvim
              telescope-nvim
              telescope-fzf-native-nvim
              telescope-ui-select-nvim
              plenary-nvim
              nvim-lspconfig
              gitsigns-nvim
              render-markdown-nvim
              neogit
              diffview-nvim
              nvim-web-devicons
              nvim-highlight-colors
              which-key-nvim
              (nvim-treesitter.withPlugins (plugins: [ plugins.mermaid ]))
              mermaid-nvim
            ];
          })
        ];

        files = {
          ".config/nvim/init.lua".source = ../../dots/neovim/init.lua;
          ".config/nvim/colors/oxocarbon.lua".source = ../../dots/neovim/colors/oxocarbon.lua;
          ".config/nvim/lua/lualine/themes/oxocarbon.lua".source = ../../dots/neovim/lualine-oxocarbon.lua;
          ".config/nvim/lua/palette.lua".text = "return ${
            lib.generators.toLua { } { inherit (theme) name colors ansi; }
          }\n";
        };
      };
  };
}
