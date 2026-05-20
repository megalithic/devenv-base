{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.devenv-base.ai;
  baseServers = (builtins.fromJSON (builtins.readFile ./mcp.json)).mcpServers;
  merged = baseServers // cfg.mcp.extraServers;
  mcpConfig = pkgs.writeText "mcp.json" (builtins.toJSON { mcpServers = merged; });
  postEditHook = pkgs.writeText "post-edit-hook.ts" (builtins.readFile ./post-edit-hook.ts);
  postEditHookArg = if cfg.postEditHook.enable then postEditHook else "";
in
{
  options.devenv-base.ai = {
    enable = lib.mkEnableOption "devenv-base AI tooling" // {
      default = true;
    };

    mcp.extraServers = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = { };
    };

    postEditHook.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Symlink post-edit-hook.ts into .pi/extensions/ on shell entry.
        Disable to skip per-edit hook latency; rely on commit-time hooks instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    claude.code.enable = lib.mkForce false;

    enterShell = "bash ${./enter-shell.sh} ${mcpConfig} ${postEditHookArg}";
  };
}
