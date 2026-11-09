{ den, ... }:

{
  den.aspects.ai.includes = [ (den.batteries.unfree [ "claude-code" ]) ];
  den.aspects.ai.hjem = { pkgs, ... }: {
    packages = with pkgs; [
      claude-code
    ];

    files.".config/fish/conf.d/claude-modes.fish".text = ''
      function build
          claude --add-dir "/home/miko/Documents/Notes" --settings '{"outputStyle":"Proactive"}' $argv
      end

      function brainstorm
          claude --add-dir "/home/miko/Documents/Notes" --permission-mode plan --settings '{"outputStyle":"Brainstorm"}' $argv
      end

      function learn
          cd "/home/miko/Projects/practice"
          and nix shell nixpkgs#nodejs --command claude --add-dir "/home/miko/Documents/Notes" --settings '{"outputStyle":"Tutor"}' $argv
      end
    '';
  };
}
