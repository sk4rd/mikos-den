set_shortcut() {
  kwriteconfig6 --file kglobalshortcutsrc --group "$1" --key "$2" "$3"
}

set_shortcut ksmserver 'Lock Session' $'Screensaver\tMeta+Ctrl+L,Screensaver\tMeta+L,Lock Session'
set_shortcut kwin 'Switch Window Left' 'Meta+H,Meta+Alt+Left,Switch to Window to the Left'
set_shortcut kwin 'Switch Window Down' 'Meta+J,Meta+Alt+Down,Switch to Window Below'
set_shortcut kwin 'Switch Window Up' 'Meta+K,Meta+Alt+Up,Switch to Window Above'
set_shortcut kwin 'Switch Window Right' 'Meta+L,Meta+Alt+Right,Switch to Window to the Right'
set_shortcut kwin 'Window Quick Tile Left' 'Meta+Shift+H,Meta+Left,Quick Tile Window to the Left'
set_shortcut kwin 'Window Quick Tile Bottom' 'Meta+Shift+J,Meta+Down,Quick Tile Window to the Bottom'
set_shortcut kwin 'Window Quick Tile Top' 'Meta+Shift+K,Meta+Up,Quick Tile Window to the Top'
set_shortcut kwin 'Window Quick Tile Right' 'Meta+Shift+L,Meta+Right,Quick Tile Window to the Right'
# Meta+T opens Ghostty, see ghostty.nix.
set_shortcut kwin 'Edit Tiles' 'none,Meta+T,Toggle Tiles Editor'
