{ config, inputs, ... }:

let
  inherit (config) theme;
in
{
  den.aspects.neovim = {
    provides.to-hosts.nixos.environment.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    provides.to-hosts.nixos.xdg.mime.defaultApplications = {
      "application/x-shellscript" = "nvim.desktop";
      "text/english" = "nvim.desktop";
      "text/plain" = "nvim.desktop";
      "text/x-c" = "nvim.desktop";
      "text/x-c++" = "nvim.desktop";
      "text/x-c++hdr" = "nvim.desktop";
      "text/x-c++src" = "nvim.desktop";
      "text/x-chdr" = "nvim.desktop";
      "text/x-csrc" = "nvim.desktop";
      "text/x-java" = "nvim.desktop";
      "text/x-makefile" = "nvim.desktop";
      "text/x-moc" = "nvim.desktop";
      "text/x-pascal" = "nvim.desktop";
      "text/x-tcl" = "nvim.desktop";
      "text/x-tex" = "nvim.desktop";
    };

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
              fyler-nvim
              (nvim-treesitter.withPlugins (p: [
                p.bash
                p.nix
              ]))
              nvim-highlight-colors
              which-key-nvim
              claudecode-nvim
              (pkgs.vimUtils.buildVimPlugin {
                pname = "walkthrough-nvim";
                version = "unstable-${inputs.walkthrough-nvim.shortRev}";
                src = inputs.walkthrough-nvim;
              })
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
