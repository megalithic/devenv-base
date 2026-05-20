{
  lib,
  config,
  ...
}:
let
  cfg = config.devenv-base.nvim;
in
{
  options.devenv-base.nvim = {
    enable = lib.mkEnableOption "devenv-base Neovim config" // {
      default = true;
    };

    extraLsps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      baseLsps = [
        "nixd"
        "bashls"
      ];
      baseLines = [
        "vim.cmd([[set runtimepath+=.nvim]])"
      ]
      ++ map (lsp: ''vim.lsp.enable("${lsp}")'') baseLsps;
      extraLines =
        map (lsp: ''vim.lsp.enable("${lsp}")'') cfg.extraLsps
        ++ lib.optional (cfg.extraConfig != "") cfg.extraConfig;
      content =
        "-- ### devenv-base nvim
"
        + lib.concatStringsSep "
" baseLines
        + "
"
        + "-- ### end
"
        + lib.optionalString (extraLines != [ ]) ("
" + lib.concatStringsSep "
" extraLines + "
");
    in
    {
      files.".nvim.lua".text = content;
    }
  );
}
