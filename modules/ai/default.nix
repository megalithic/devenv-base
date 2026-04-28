{
  lib,
  pkgs,
  config,
  ...
}:
let
  baseServers = (builtins.fromJSON (builtins.readFile ./mcp.json)).mcpServers;
  merged = baseServers // config.devenv-base.ai.mcp.extraServers;
  mcpConfig = pkgs.writeText "mcp.json" (builtins.toJSON { mcpServers = merged; });
  postEditHook = pkgs.writeText "post-edit-hook.ts" (builtins.readFile ./post-edit-hook.ts);
  postEditHookArg = if config.devenv-base.ai.postEditHook.enable then postEditHook else "";
in
{
  options.devenv-base.ai.mcp.extraServers = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
  };

  options.devenv-base.ai.postEditHook.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Symlink post-edit-hook.ts into .pi/extensions/ on shell entry.
      Disable to skip per-edit hook latency; rely on commit-time hooks instead.
    '';
  };

  config = {
    claude.code.enable = lib.mkForce false;

    enterShell = "bash ${./enter-shell.sh} ${mcpConfig} ${postEditHookArg}";
  };
}
