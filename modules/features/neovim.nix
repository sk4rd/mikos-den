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
        host,
        pkgs,
        lib,
        ...
      }:
      let
        inherit (host) theme;
      in
      {
        packages = [
          pkgs.ripgrep
          pkgs.nixd
          pkgs.nixfmt
          pkgs.lua-language-server
          pkgs.jjui
          (pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
            wrapRc = false;
            plugins = with pkgs.vimPlugins; [
              lualine-nvim
              telescope-nvim
              telescope-fzf-native-nvim
              telescope-ui-select-nvim
              plenary-nvim
              gitsigns-nvim
              hunk-nvim
              nui-nvim
              diffview-plus-nvim
              nvim-web-devicons
              fyler-nvim
              (nvim-treesitter.withPlugins (p: [
                p.bash
                p.nix
              ]))
              nvim-highlight-colors
              which-key-nvim
              claudecode-nvim
            ];
          })
        ];

        files = {
          ".config/nvim/init.lua".source = ../../dots/neovim/init.lua;
          ".config/jj/conf.d/neovim.toml".text = ''
            [ui]
            diff-editor = ["nvim", "-c", "DiffEditor $left $right $output"]
          '';
          ".config/nvim/colors/${theme.name}.lua".source = ../../dots/neovim/colorscheme.lua;
          ".config/nvim/lua/lualine/themes/${theme.name}.lua".source = ../../dots/neovim/lualine-theme.lua;
          ".config/nvim/lua/palette.lua".text = "return ${
            lib.generators.toLua { } {
              inherit (theme)
                name
                variant
                colors
                ansi
                ;
            }
          }\n";
        };
      };
  };
}
