{
  den.aspects.neovim.hjem = { pkgs, ... }: {
    packages = [
      (pkgs.wrapNeovimUnstable pkgs.neovim-unwrapped {
        # Don't override the init.el path
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/editors/neovim/wrapper.nix#L69-L72
        wrapRc = false;
        plugins = with pkgs.vimPlugins; [
          lualine-nvim
        ];
      })
    ];
  };
}
