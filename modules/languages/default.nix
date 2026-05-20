{
  lib,
  config,
  ...
}:
let
  cfg = config.devenv-base.languages;
in
{
  options.devenv-base.languages.enable = lib.mkEnableOption "devenv-base languages" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    languages = {
      nix.enable = true;
      shell.enable = true;
    };
  };
}
