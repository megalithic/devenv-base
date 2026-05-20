{
  pkgs,
  inputs,
  lib,
  config,
  ...
}:
let
  cfg = config.devenv-base.treefmt;
  treefmt-nix = import inputs.treefmt-nix;
  treefmtConfig = builtins.removeAttrs cfg [ "enable" ];
  treefmtEval = treefmt-nix.evalModule pkgs {
    imports = [
      {
        projectRootFile = "devenv.nix";
        settings.global.excludes = [
          "*.lock"
          "*.lockb"
          ".devenv*"
          "package-lock.json"
          "pnpm-lock.yaml"
        ];
        programs = {
          nixfmt.enable = true;
          prettier.enable = true;
          shfmt.enable = true;
        };
      }
      treefmtConfig
    ];
  };
in
{
  options.devenv-base.treefmt = lib.mkOption {
    type = lib.types.submodule {
      freeformType = lib.types.attrs;
      options.enable = lib.mkEnableOption "devenv-base treefmt setup" // {
        default = true;
      };
    };
    default = { };
  };

  config = lib.mkIf cfg.enable {
    packages = [
      treefmtEval.config.build.wrapper
    ];

    tasks."nix:format" = {
      description = "Run treefmt formatters";
      exec = "treefmt -v";
    };

    git-hooks.hooks.treefmt = {
      enable = true;
      package = treefmtEval.config.build.wrapper;
    };
  };
}
