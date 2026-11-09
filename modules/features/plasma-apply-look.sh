[ "$(kreadconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage)" = org.kde.breezedark.desktop ] ||
  plasma-apply-lookandfeel --apply org.kde.breezedark.desktop

# The look-and-feel package doesn't replace user overrides of these.
plasma-apply-colorscheme BreezeDark
plasma-apply-desktoptheme breeze-dark
kwriteconfig6 --file kdeglobals --group Icons --key Theme breeze-dark
