{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.devenv-base.tk;
  tk = pkgs.stdenvNoCC.mkDerivation {
    pname = "tk";
    version = "v0.3.2-patched";
    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/wedow/ticket/v0.3.2/ticket";
      hash = "sha256-QI8sET7MO8BxUHWTp4OG8bTMdDvmSRyenyYn79TZkCs=";
    };
    dontUnpack = true;
    installPhase = ''
      install -Dm755 $src $out/bin/tk
      substituteInPlace $out/bin/tk \
        --replace-fail \
          'dir_name=$(basename "$(pwd)")' \
          'dir_name=$(basename "$(pwd)" | tr -d -c "a-zA-Z0-9-_")' \
        --replace-fail \
          '[[ ''${#prefix} -lt 2 ]] && prefix="''${dir_name:0:3}"' \
          '[[ ''${#prefix} -lt 3 ]] && prefix="''${dir_name:0:3}"'
    '';
  };
in
{
  options.devenv-base.tk.enable = lib.mkEnableOption "devenv-base tk ticket CLI" // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    packages = [
      tk
    ];
  };
}
