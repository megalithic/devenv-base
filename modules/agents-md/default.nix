{
  lib,
  pkgs,
  config,
  ...
}:
let
  baseContent = builtins.readFile ./BASE_AGENTS.md;

  # Strip the "## Tickets and tasks" section (header through the next H2 or EOF).
  # Splits on the section header, then re-joins everything from the next H2 onward.
  stripTkSection =
    content:
    let
      parts = lib.splitString "\n## Tickets and tasks\n" content;
    in
    if builtins.length parts < 2 then
      content
    else
      let
        before = builtins.head parts;
        rest = lib.concatStringsSep "\n## Tickets and tasks\n" (builtins.tail parts);
        afterParts = lib.splitString "\n## " rest;
        afterTk =
          if builtins.length afterParts > 1 then
            "\n## " + lib.concatStringsSep "\n## " (builtins.tail afterParts)
          else
            "";
      in
      before + afterTk;

  filteredBase =
    if config.devenv-base.agents-md.includeTk then baseContent else stripTkSection baseContent;

  agentsMdContent =
    filteredBase
    + (lib.optionalString (config.devenv-base.agents-md.extraEntries != [ ]) (
      "\n\n" + (lib.concatStringsSep "\n" config.devenv-base.agents-md.extraEntries) + "\n"
    ));
in
{
  options.devenv-base.agents-md.extraEntries = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };

  options.devenv-base.agents-md.includeTk = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Include the "## Tickets and tasks" section from BASE_AGENTS.md.
      Disable when the consuming project uses a different ticket workflow
      (e.g. skills/task-pipeline).
    '';
  };

  config = {
    enterShell = "bash ${./enter-shell.sh} ${pkgs.writeText "agents-md" agentsMdContent}";
  };
}
