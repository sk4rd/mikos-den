{ den, lib }:
let
  inherit (lib) mkOption types;
  inherit (den.lib.aspects.fx.keyClassification) isStructuralKey;

  # Pipeline, class and quirk keys are never child aspects.
  skipKey =
    k:
    isStructuralKey k
    || (den.classes or { }) ? ${k}
    || (den.quirks or { }) ? ${k};

  reshape =
    raw:
    if raw ? options || raw ? config || raw ? imports then raw else { options = raw; };

  hasSettingsDeep =
    node:
    builtins.isAttrs node
    && (
      node ? settings
      || lib.any (k: !(skipKey k) && hasSettingsDeep (node.${k} or null)) (builtins.attrNames node)
    );

  nodeModule =
    node:
    let
      own = reshape (node.settings or { });
      children = lib.filterAttrs (
        k: v: !(skipKey k) && builtins.isAttrs v && hasSettingsDeep v
      ) node;
    in
    {
      imports = own.imports or [ ];
      config = own.config or { };
      options =
        (own.options or { })
        // lib.mapAttrs (name: child: mkOption {
          type = types.submodule (nodeModule child);
          default = { };
          description = "Settings under ${name}";
        }) children;
    };
in
types.submodule (nodeModule (den.aspects or { }))
