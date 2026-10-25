{ den, ... }:

{
  den.aspects.neovim = {
    includes = [ den.aspects.theme ];

    hjem =
      { pkgs, config, lib, ... }:
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
              plenary-nvim
              nvim-lspconfig
              gitsigns-nvim
              render-markdown-nvim
              neogit
              diffview-nvim
              nvim-web-devicons
              nvim-highlight-colors
              which-key-nvim
            ];
          })
        ];

        files = {
          ".config/nvim/init.lua".source = ../../dots/neovim/init.lua;
          ".config/nvim/lua/theme.lua".source = ../../dots/neovim/theme.lua;
          ".config/nvim/lua/palette.lua".text = "return ${lib.generators.toLua { } config.miko.theme};\n";
        };
      };
  };
}
