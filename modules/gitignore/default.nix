{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.devenv-base.gitignore;
in
{
  options.devenv-base.gitignore = {
    enable = lib.mkEnableOption "devenv-base managed .gitignore" // {
      default = true;
    };

    extraEntries = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable (
    let
      baseEntries = [
        ".devenv*"
        ".gitignore"
        ".nvim.lua"
        ".pre-commit-config.yaml"
        ".pi"
        "devenv.local.nix"
        "devenv.local.yaml"
      ]
      ++ lib.optional config.devenv-base.lat-md.enable "lat.md/.cache/"
      ++ [
        "result"
      ];
      gitignoreFile = pkgs.writeText "gitignore" (
        "### devenv-base gitignore\n"
        + (lib.concatStringsSep "\n" baseEntries)
        + "\n"
        + "### end\n"
        + (lib.optionalString (cfg.extraEntries != [ ]) (
          "\n" + lib.concatStringsSep "\n" cfg.extraEntries + "\n"
        ))
      );
    in
    {
      enterShell = "bash ${./enter-shell.sh} ${gitignoreFile}";
    }
  );
}
