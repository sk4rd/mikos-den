{ config, den, ... }:

let
  c = config.theme.colors;
  h = config.theme.lib.bare;
in
{
  # Globals shadow fish's universal colour variables, so the theme always wins.
  den.aspects.fish.hjem.files.".config/fish/conf.d/theme.fish".text = ''
    set -g fish_color_normal ${h c.fg}
    set -g fish_color_command ${h c.blue}
    set -g fish_color_keyword ${h c.blue}
    set -g fish_color_param ${h c.subtle}
    set -g fish_color_option ${h c.cyan}
    set -g fish_color_quote ${h c.purple}
    set -g fish_color_escape ${h c.pink}
    set -g fish_color_redirection ${h c.teal}
    set -g fish_color_end ${h c.teal}
    set -g fish_color_operator ${h c.cyan}
    set -g fish_color_error ${h c.error}
    set -g fish_color_comment ${h c.muted} --italics
    set -g fish_color_autosuggestion ${h c.muted}
    set -g fish_color_valid_path --underline
    set -g fish_color_cwd ${h c.blue}
    set -g fish_color_cwd_root ${h c.error}
    set -g fish_color_user ${h c.green}
    set -g fish_color_host ${h c.subtle}
    set -g fish_color_host_remote ${h c.yellow}
    set -g fish_color_status ${h c.error}
    set -g fish_color_cancel --reverse
    set -g fish_color_selection --background=${h c.selection}
    set -g fish_color_search_match --background=${h c.selection}
    set -g fish_color_history_current --bold

    set -g fish_pager_color_progress ${h c.muted}
    set -g fish_pager_color_prefix ${h c.blue} --bold
    set -g fish_pager_color_completion ${h c.fg}
    set -g fish_pager_color_description ${h c.muted}
    set -g fish_pager_color_selected_background --background=${h c.overlay}
    set -g fish_pager_color_selected_prefix ${h c.blue} --bold
    set -g fish_pager_color_selected_completion ${h c.fgBright}
    set -g fish_pager_color_selected_description ${h c.subtle}
  '';

  den.schema.user.includes = [ den.aspects.fish ];
}
