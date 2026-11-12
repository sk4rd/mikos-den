{ lib, theme }:
let
  c = theme.colors;
  vars = {
    color-base-00 = c.bg;
    color-base-05 = c.bg;
    color-base-10 = c.surface;
    color-base-20 = c.surface;
    color-base-25 = c.overlay;
    color-base-30 = c.overlay;
    color-base-35 = c.muted;
    color-base-40 = c.muted;
    color-base-50 = c.dim;
    color-base-60 = c.dim;
    color-base-70 = c.subtle;
    color-base-100 = c.fg;

    color-red = c.error;
    color-orange = c.orange;
    color-yellow = c.warning;
    color-green = c.success;
    color-cyan = c.cyan;
    color-blue = c.blue;
    color-purple = c.purple;
    color-pink = c.pink;
    color-accent = c.accent;
    color-accent-1 = "color-mix(in srgb, ${c.accent} 85%, ${c.fgBright})";
    color-accent-2 = "color-mix(in srgb, ${c.accent} 70%, ${c.fgBright})";

    background-primary = c.bg;
    background-primary-alt = c.surface;
    background-secondary = c.bgDim;
    background-secondary-alt = c.bg;
    background-modifier-hover = c.overlay;
    background-modifier-active-hover = c.selection;
    background-modifier-border = c.overlay;
    background-modifier-border-hover = c.muted;
    background-modifier-border-focus = c.accent;
    background-modifier-form-field = c.surface;
    background-modifier-error = "color-mix(in srgb, ${c.error} 20%, ${c.bg})";
    background-modifier-error-hover = "color-mix(in srgb, ${c.error} 30%, ${c.bg})";
    background-modifier-success = "color-mix(in srgb, ${c.success} 20%, ${c.bg})";
    background-modifier-message = c.surface;

    interactive-normal = c.surface;
    interactive-hover = c.overlay;
    interactive-accent = "var(--color-accent)";
    interactive-accent-hover = "var(--color-accent-1)";

    text-normal = c.fg;
    text-muted = c.subtle;
    text-faint = c.dim;
    # Oxocarbon's accent is light, so buttons need dark labels.
    text-on-accent = c.bg;
    text-on-accent-inverted = c.bg;
    text-success = c.success;
    text-warning = c.warning;
    text-error = c.error;
    text-accent = "var(--color-accent)";
    text-accent-hover = "var(--color-accent-1)";
    text-selection = c.selection;
    text-highlight-bg = "color-mix(in srgb, ${c.warning} 25%, transparent)";
    caret-color = c.cursor;

    link-color = "var(--color-accent)";
    link-color-hover = "var(--color-accent-1)";
    link-external-color = c.cyan;
    link-external-color-hover = c.teal;
    tag-color = c.purple;
    tag-color-hover = c.pink;
    tag-background = "color-mix(in srgb, ${c.purple} 15%, transparent)";
    tag-background-hover = "color-mix(in srgb, ${c.purple} 25%, transparent)";
    blockquote-border-color = c.accentAlt;
    hr-color = c.overlay;

    code-background = c.surface;
    code-normal = c.subtle;
    code-comment = c.dim;
    code-function = c.syntax.function;
    code-important = c.syntax.decorator;
    code-keyword = c.syntax.keyword;
    code-operator = c.syntax.operator;
    code-property = c.syntax.property;
    code-punctuation = c.syntax.punctuation;
    code-string = c.syntax.string;
    code-tag = c.syntax.type;
    code-value = c.syntax.number;
  };
in
''
  body {
    --font-interface-theme: "${theme.fonts.ui.name}", sans-serif;
    --font-text-theme: "${theme.fonts.ui.name}", sans-serif;
    --font-monospace-theme: "${theme.fonts.mono.name}", monospace;
  }

  .theme-dark {
  ${lib.concatStrings (lib.mapAttrsToList (name: value: "  --${name}: ${value};\n") vars)}}
''
