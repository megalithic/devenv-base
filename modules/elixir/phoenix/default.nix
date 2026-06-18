# ─── devenv-base: elixir.phoenix sub-module ─────────────────────────────────
# Wires processes.phoenix (port reservation only; started manually via
# start-phx), the start-phx script (with PGPORT export fix), the unified
# status script, tidewave MCP server, and the app:* mix tasks.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.devenv-base.elixir.phoenix;
  parent = config.devenv-base.elixir;

  configInt = parent._configInt;
  toolVersions = parent._toolVersions;
  erlangAttr = parent._erlangAttr;
  elixirAttr = parent._elixirAttr;
  expertPkg = parent.lsp.expert.package;

  envInt =
    name: default:
    let
      p = builtins.getEnv name;
    in
    if p == "" then default else lib.strings.toInt p;

  httpPortFromConfig = configInt ".*Endpoint" "port" 4000;

  pgAllocated = toString config.processes.postgres.ports.main.value;
  phxAllocated = toString config.processes.phoenix.ports.http.value;
in
{
  options.devenv-base.elixir.phoenix = {
    enable = lib.mkEnableOption "devenv-base Elixir Phoenix sub-module" // {
      default = false;
    };
    tidewave.enable = lib.mkEnableOption "tidewave MCP server" // {
      default = true;
    };
  };

  config = lib.mkIf (parent.enable && cfg.enable) {
    # ── Port reservation (devenv up does NOT start phoenix) ───────────────
    processes.phoenix = {
      ports.http.allocate = envInt "PORT" httpPortFromConfig;
      start.enable = false;
      exec = "true";
    };

    # ── status script ──────────────────────────────────────────────────────
    scripts.status.exec = ''
      echo ""
      MAIN_TREE="$(git worktree list --porcelain 2>/dev/null | head -1 | sed 's/^worktree //')"
      if [ -n "$MAIN_TREE" ] && [ "$MAIN_TREE" != "$PWD" ]; then
        HEADER="$(basename "$MAIN_TREE")/$(basename "$PWD")"
      else
        HEADER="$(basename "$PWD")"
      fi
      APP_NAME="${parent._appName}"
      if [ -n "$APP_NAME" ]; then
        HEADER="$HEADER ($APP_NAME)"
      fi
      echo "$HEADER"
      echo " erlang*  ${toolVersions.erlang}/${erlangAttr}"
      echo " elixir*  ${toolVersions.elixir}/${elixirAttr}"
      ${lib.optionalString parent.lsp.expert.enable ''echo " expert   ${expertPkg.version}"''}
      echo " node     $(node --version | sed 's/^v//')"
      PG_PID_FILE="''${DEVENV_STATE:-$PWD/.devenv/state}/postgres/postmaster.pid"
      if [ -f "$PG_PID_FILE" ] && kill -0 "$(head -1 "$PG_PID_FILE")" 2>/dev/null; then
        PG_PORT="$(sed -n '4p' "$PG_PID_FILE")"
        echo " pg       ${pkgs.postgresql_18.version} :$PG_PORT (allocated ${pgAllocated})"
      else
        echo " pg       ${pkgs.postgresql_18.version} (not running, allocated ${pgAllocated})"
      fi
      PHX_PORT_FILE="''${DEVENV_STATE:-$PWD/.devenv/state}/phoenix.port"
      if [ -f "$PHX_PORT_FILE" ] && lsof -iTCP:"$(cat "$PHX_PORT_FILE")" -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo " phoenix  :$(cat "$PHX_PORT_FILE")"
      else
        echo " phoenix  (not running, allocated ${phxAllocated})"
      fi
      echo " tidewave  http://localhost:${phxAllocated}/tidewave/mcp"
      echo ""
      export PI_MCP_URL=http://localhost:${phxAllocated}/tidewave/mcp
      export PI_DISABLE_EMBEDDED=1
      export PI_ELIXIR_DEBUG=1
      export PI_ELIXIR_DEBUG_LOG=/tmp/pi-elixir-debug.json
    '';

    # ── start-phx script ───────────────────────────────────────────────────
    # Waits for postgres, picks a free phoenix port, exports PGPORT so the
    # running app connects to THIS worktree's DB (not the main checkout's).
    scripts.start-phx.exec = ''
      PG_PID_FILE="''${DEVENV_STATE:-$PWD/.devenv/state}/postgres/postmaster.pid"
      if [ -f "$PG_PID_FILE" ] && kill -0 "$(head -1 "$PG_PID_FILE")" 2>/dev/null; then
        PG_PORT="$(sed -n '4p' "$PG_PID_FILE")"
      else
        PG_PORT="${pgAllocated}"
      fi
      echo "waiting for postgres on port $PG_PORT..."
      until pg_isready -h "''${HOST:-127.0.0.1}" -p "$PG_PORT" -q; do
        sleep 1
      done
      PHX_PORT="$(free-port ${phxAllocated})"
      PHX_PORT_FILE="''${DEVENV_STATE:-$PWD/.devenv/state}/phoenix.port"
      echo "$PHX_PORT" > "$PHX_PORT_FILE"
      # Export the worktree's actual PG port so the running app connects to
      # ITS OWN database, not the main checkout's on 5432. Without this the
      # app falls back to PGPORT=5432 → Phoenix.Ecto.PendingMigrationError (503).
      export PGPORT="$PG_PORT"
      echo "starting phoenix in iex on port $PHX_PORT (PGPORT=$PGPORT)..."
      PORT="$PHX_PORT" m s "''${SNAME:-dev-$(basename $PWD)}"
      export PI_MCP_URL=http://localhost:${phxAllocated}/tidewave/mcp
      export PI_DISABLE_EMBEDDED=1
      export PI_ELIXIR_DEBUG=1
      export PI_ELIXIR_DEBUG_LOG=/tmp/pi-elixir-debug.json
    '';

    # ── mix tasks ─────────────────────────────────────────────────────────
    tasks = {
      "app:setup" = {
        description = "Fully setup the app (hex, rebar, deps, assets, db)";
        exec = ''
          mix local.hex --force
          mix local.rebar --force
          mix setup
        '';
      };
      "app:test" = {
        description = "Run mix test";
        exec = "mix test";
      };
      "app:reset-db" = {
        description = "Fully re-create the dev and test databases";
        exec = ''
          mix ecto.reset
          MIX_ENV=test mix ecto.reset
          m s "''${SNAME:-dev-$(basename $PWD)}"
        '';
      };
    };

    # ── enterShell ────────────────────────────────────────────────────────
    enterShell = ''
      status
    '';

    # ── tidewave MCP server ───────────────────────────────────────────────
    devenv-base.ai.mcp.extraServers = lib.mkIf cfg.tidewave.enable {
      tidewave = {
        type = "streamable-http";
        url = "http://localhost:${phxAllocated}/tidewave/mcp";
        lifecycle = "keep-alive";
      };
    };
  };
}
