{ config, ... }:

let
  inherit (config) theme;
in
{
  den.aspects.neovim = {
    provides.to-hosts.nixos.environment.variables.EDITOR = "nvim";

    hjem =
      {
        pkgs,
        lib,
        ...
      }:
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
              gitsigns-nvim
              neogit
              diffview-nvim
              nvim-web-devicons
              nvim-tree-lua
              nvim-highlight-colors
              which-key-nvim
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
