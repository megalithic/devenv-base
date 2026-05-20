{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.devenv-base.agents-md;
  baseContent = builtins.readFile ./BASE_AGENTS.md;

  # Strip a top-level section (header through the next H2 or EOF).
  # Used when generated AGENTS.md would otherwise mention disabled modules.
  stripSection =
    section: content:
    let
      header = "\n## ${section}\n";
      parts = lib.splitString header content;
    in
    if builtins.length parts < 2 then
      content
    else
      let
        before = builtins.head parts;
        rest = lib.concatStringsSep header (builtins.tail parts);
        afterParts = lib.splitString "\n## " rest;
        afterSection =
          if builtins.length afterParts > 1 then
            "\n## " + lib.concatStringsSep "\n## " (builtins.tail afterParts)
          else
            "";
      in
      before + afterSection;

  filteredBase = lib.pipe baseContent (
    lib.optional (!cfg.includeTk || !config.devenv-base.tk.enable) (stripSection "Tickets and tasks")
    ++ lib.optional (!config.devenv-base.lat-md.enable) (stripSection "Lat")
  );

  agentsMdContent =
    filteredBase
    + (lib.optionalString (cfg.extraEntries != [ ]) (
      "\n\n" + (lib.concatStringsSep "\n" cfg.extraEntries) + "\n"
    ));
in
{
  options.devenv-base.agents-md = {
    enable = lib.mkEnableOption "devenv-base AGENTS.md setup" // {
      default = true;
    };

    extraEntries = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    includeTk = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Include the "## Tickets and tasks" section from BASE_AGENTS.md.
        Disable when the consuming project uses a different ticket workflow
        (e.g. skills/task-pipeline). The section is also omitted when
        devenv-base.tk.enable is false.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    enterShell = "bash ${./enter-shell.sh} ${pkgs.writeText "agents-md" agentsMdContent}";
  };
}
