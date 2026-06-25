# ─── devenv-base: elixir.phoenix sub-module ─────────────────────────────────
# Wires start-phx, the unified status script, the tidewave MCP server, and the
# app:* mix tasks.
#
# Ports are NOT allocated/freed by devenv. config/dev.exs derives the Phoenix
# port deterministically from GIT_WORKTREE:
#   port = base + :erlang.phash2(GIT_WORKTREE, 1000)   (base = Endpoint :port)
# The `phx-port` script mirrors that formula (using the project's elixir) and
# exports PHX_PORT so status + the tidewave URL point at the running server.
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

  httpPortFromConfig = configInt ".*Endpoint" "port" 4000;
  pgPort = configInt ".*Repo" "port" 5432;
  elixirPkg = parent._elixirPkg;
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
    scripts = {
      # ── phx-port: deterministic Phoenix port (mirrors config/dev.exs) ──────
      # base + :erlang.phash2(GIT_WORKTREE, 1000); base from Endpoint :port.
      phx-port.exec = ''
        ${elixirPkg}/bin/elixir -e '
          off =
            case System.get_env("GIT_WORKTREE") do
              w when w in [nil, ""] -> 0
              w -> :erlang.phash2(w, 1000)
            end
          IO.puts(${toString httpPortFromConfig} + off)
        '
      '';

      # ── status script ──────────────────────────────────────────────────────
      status.exec = ''
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
        if pg_isready -h 127.0.0.1 -p ${toString pgPort} -q 2>/dev/null; then
          echo " pg       ${pkgs.postgresql_18.version} :${toString pgPort}"
        else
          echo " pg       ${pkgs.postgresql_18.version} (not running, :${toString pgPort})"
        fi
        if lsof -iTCP:"$PHX_PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
          echo " phoenix  :$PHX_PORT"
        else
          echo " phoenix  (not running, :$PHX_PORT)"
        fi
        echo " tidewave  http://localhost:$PHX_PORT/tidewave/mcp"
        echo ""
        export PI_MCP_URL="http://localhost:$PHX_PORT/tidewave/mcp"
        export PI_DISABLE_EMBEDDED=1
        export PI_ELIXIR_DEBUG=1
        export PI_ELIXIR_DEBUG_LOG=/tmp/pi-elixir-debug.json
      '';

      # ── start-phx script ───────────────────────────────────────────────────
      # Waits for the shared postgres, then boots iex. The Phoenix port and the
      # database name are both derived from GIT_WORKTREE in config/dev.exs, so no
      # port hunting or PGPORT rewriting is needed here.
      start-phx.exec = ''
        echo "waiting for postgres on port ${toString pgPort}..."
        until pg_isready -h 127.0.0.1 -p ${toString pgPort} -q; do
          sleep 1
        done
        echo "starting phoenix in iex on port ''${PHX_PORT:-$(phx-port)}..."
        m s "''${SNAME:-dev-$(basename $PWD)}"
      '';
    };

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
    # Export PHX_PORT early (mkBefore) so the ai module can substitute it into
    # .pi/mcp.json (tidewave URL) and `status` can display it.
    enterShell = lib.mkMerge [
      (lib.mkBefore ''
        export PHX_PORT="$(phx-port)"
      '')
      ''
        status
      ''
    ];

    # ── tidewave MCP server ───────────────────────────────────────────────
    # URL keeps a literal ''${PHX_PORT} placeholder; the ai module substitutes
    # the deterministic Phoenix port when materializing .pi/mcp.json.
    devenv-base.ai.mcp.extraServers = lib.mkIf cfg.tidewave.enable {
      tidewave = {
        type = "streamable-http";
        url = "http://localhost:\${PHX_PORT}/tidewave/mcp";
        lifecycle = "keep-alive";
      };
    };
  };
}
