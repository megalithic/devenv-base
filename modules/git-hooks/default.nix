{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.devenv-base.git-hooks;
in
{
  options.devenv-base.git-hooks.enable = lib.mkEnableOption "devenv-base git hooks" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    git-hooks.hooks = {
      check-merge-conflicts.enable = true;
      deadnix.enable = true;
      detect-private-keys.enable = true;
      shellcheck = {
        enable = true;
        entry = "${pkgs.shellcheck}/bin/shellcheck --severity=warning";
      };
      typos = {
        enable = true;
        excludes = [ "\.tickets/" ];
      };
      commitlint = {
        enable = true;
        stages = [ "commit-msg" ];
        entry = "${pkgs.commitlint}/bin/commitlint --extends @commitlint/config-conventional --edit";
      };
      gitleaks = {
        enable = true;
        entry = "${pkgs.gitleaks}/bin/gitleaks protect --staged --verbose";
      };
      statix = {
        enable = true;
        entry = "${pkgs.statix}/bin/statix check --format errfmt --ignore .devenv,.devenv.* .";
        pass_filenames = false;
      };
    };
  };
}
