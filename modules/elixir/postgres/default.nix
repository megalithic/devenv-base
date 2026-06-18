# ─── devenv-base: elixir.postgres sub-module ────────────────────────────────
# Wires up services.postgres using the port from config/dev.exs (or PGPORT env),
# creates dev/test databases, and contributes the postgres section to `status`.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.devenv-base.elixir.postgres;
  parent = config.devenv-base.elixir;

  configInt = parent._configInt;
  appName = parent._appName;

  envInt =
    name: default:
    let
      p = builtins.getEnv name;
    in
    if p == "" then default else lib.strings.toInt p;

  pgPortFromConfig = configInt ".*Repo" "port" 5432;
in
{
  options.devenv-base.elixir.postgres = {
    enable = lib.mkEnableOption "devenv-base Elixir postgres service" // {
      default = false;
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql_18;
      description = "PostgreSQL package to use.";
    };
    extraInitialDatabases = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.str);
      default = [ ];
      description = "Additional databases to create beyond the default dev/test pair.";
    };
  };

  config = lib.mkIf (parent.enable && cfg.enable) {
    packages = [ pkgs.postgresql_18 ]; # psql client

    env = {
      PG_DEV_TABLE = "${appName}_dev";
      PG_TEST_TABLE = "${appName}_test";
    };

    services.postgres = {
      enable = true;
      inherit (cfg) package;
      listen_addresses = builtins.getEnv "HOST";
      port = envInt "PGPORT" pgPortFromConfig;
      initialDatabases = [
        { name = builtins.getEnv "PG_DEV_TABLE"; }
        { name = builtins.getEnv "PG_TEST_TABLE"; }
      ]
      ++ cfg.extraInitialDatabases;
      initialScript = ''
        CREATE USER postgres SUPERUSER PASSWORD 'postgres';
      '';
    };
  };
}
