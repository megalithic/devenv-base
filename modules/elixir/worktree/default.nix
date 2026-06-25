# ─── devenv-base: elixir.worktree sub-module ────────────────────────────────
# Handles git worktree lifecycle for Elixir/Phoenix projects:
#   - enterShell: derives SNAME from the worktree dir (using the -A2 fix),
#     exports disableListeners entries when inside a non-main worktree
#   - worktree:setup  — cold-build: pg start, deps, assets, ecto.reset dev+test
#   - worktree:services — start-phx (requires phoenix sub-module)
#   - worktree:teardown — free phoenix port, kill iex node, devenv processes down
#
# Each task has pre-/post- hook injection points (worktrunk-style naming):
#   hooks.pre-setup, hooks.post-setup
#   hooks.pre-services, hooks.post-services
#   hooks.pre-teardown, hooks.post-teardown
{
  lib,
  config,
  ...
}:
let
  cfg = config.devenv-base.elixir.worktree;
  parent = config.devenv-base.elixir;

  pgPort = parent._configInt ".*Repo" "port" 5432;

  # Build the listener-disable export block for the worktree branch.
  # Each entry in disableListeners is a "KEY=VALUE" string.
  listenerExports = lib.concatMapStrings (kv: "  export ${kv}\n") cfg.disableListeners;
in
{
  options.devenv-base.elixir.worktree = {
    enable = lib.mkEnableOption "devenv-base Elixir worktree lifecycle tasks" // {
      default = false;
    };

    # ── Listener isolation ─────────────────────────────────────────────────
    # List of "KEY=VALUE" strings exported only when inside a non-main
    # worktree shell. Use this to disable services that would collide with the
    # main checkout (e.g. metrics servers, debug servers).
    #
    # rx example:
    #   disableListeners = [ "RX_METRICS_PORT=-1" "LIVE_DEBUGGER_DISABLED=true" ];
    # verify-doctor (no extra listeners):
    #   disableListeners = [];  # default
    disableListeners = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "RX_METRICS_PORT=-1"
        "LIVE_DEBUGGER_DISABLED=true"
      ];
      description = ''
        Environment variables to export when running inside a non-main git
        worktree. Intended for disabling listeners (metrics servers, debug
        servers) that would collide with the main checkout. Each entry must
        be a KEY=VALUE string.
      '';
    };

    # ── Pre-/post- lifecycle hooks (worktrunk-style naming) ────────────────
    # All hooks are blocking shell snippets injected at the named seam.
    # The opinionated default body still runs; hooks add to it.
    hooks = {
      pre-setup = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Shell snippet run before the worktree:setup body.";
      };
      post-setup = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Shell snippet run after the worktree:setup body succeeds.";
      };
      pre-services = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Shell snippet run before start-phx in worktree:services.";
      };
      post-services = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Shell snippet run after worktree:services (e.g. open browser, ping health).";
      };
      pre-teardown = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Shell snippet run before the worktree:teardown body.";
      };
      post-teardown = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Shell snippet run after the worktree:teardown body completes.";
      };
    };
  };

  config = lib.mkIf (parent.enable && cfg.enable) {
    # ── SNAME worktree detection (enterShell) ─────────────────────────────
    # Uses grep -A2 (not -A1) to correctly find the `branch` line in
    # `git worktree list --porcelain` output (worktree/HEAD/branch = 3 lines).
    # Also exports disableListeners when inside a non-main worktree.
    enterShell = ''
      APP_NAME="$(rg 'app:' mix.exs -m1 2>/dev/null | sed 's/.*app: :\([a-z_]*\).*/\1/' | tr '_' '-')"
      export APP_NAME="''${APP_NAME:-app}"
      if git rev-parse --is-inside-work-tree &>/dev/null \
        && [ -n "$(git worktree list --porcelain | grep -A2 "^worktree $(pwd)$" | grep '^branch ')" ] \
        && [ "$(pwd)" != "$(git worktree list --porcelain | head -2 | grep '^worktree ' | sed 's/^worktree //')" ]; then
        WORKTREE_NAME="$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')"
        # GIT_WORKTREE drives config/dev.exs: DB name suffix + deterministic
        # Phoenix/live_debugger/test ports. Exporting it here is what activates
        # per-worktree isolation; everything downstream reads from it.
        export GIT_WORKTREE="''${GIT_WORKTREE:-$WORKTREE_NAME}"
        export SNAME="''${APP_NAME}-''${GIT_WORKTREE}"
        ${listenerExports}
      else
        export SNAME="''${APP_NAME}-dev"
      fi
    '';

    tasks = {
      # ── worktree:setup ─────────────────────────────────────────────────
      "worktree:setup" = {
        description = "Fully initialize a new git worktree (start pg, install deps, reset dbs)";
        exec = ''
          ${cfg.hooks.pre-setup}

          # Worktrees share ONE postgres on port ${toString pgPort} and isolate
          # by database name (config/dev.exs appends "_$GIT_WORKTREE"). Only
          # start postgres if nothing is already serving that port.
          if ! pg_isready -h 127.0.0.1 -p ${toString pgPort} -q 2>/dev/null; then
            echo "Starting devenv processes..."
            devenv up -d
            echo "Waiting for postgres on port ${toString pgPort}..."
            for i in $(seq 1 30); do
              if pg_isready -h 127.0.0.1 -p ${toString pgPort} -q 2>/dev/null; then
                echo "Postgres ready after ''${i}s"
                break
              fi
              if [ "$i" -eq 30 ]; then
                echo "ERROR: postgres not ready after 60s, aborting"
                exit 1
              fi
              sleep 2
            done
          fi

          ${lib.concatMapStrings (kv: "export ${kv}\n") cfg.disableListeners}

          # Install build tools and dependencies.
          # mix archive.install handles edge cases with large hex packages
          # (e.g. phosphor_icons metadata.config size issues).
          mix archive.install github hexpm/hex branch main --force
          mix local.rebar --force
          mix deps.get
          mix assets.setup

          # Reset dev and test DBs. Using ecto.reset (not ecto.setup) so this
          # is idempotent — safe to re-run against a worktree that already has
          # data (drops + recreates).
          mix ecto.create || mix ecto.drop
          mix ecto.reset
          MIX_ENV=test mix ecto.reset

          ${cfg.hooks.post-setup}
        '';
      };

      # ── worktree:services ──────────────────────────────────────────────
      "worktree:services" = {
        description = "Start services for this worktree (run after worktree:setup)";
        exec = ''
          ${cfg.hooks.pre-services}
          start-phx
          ${cfg.hooks.post-services}
        '';
      };

      # ── worktree:teardown ──────────────────────────────────────────────
      "worktree:teardown" = {
        description = "Stop all services for this worktree (run BEFORE removing it)";
        exec = ''
          ${cfg.hooks.pre-teardown}

          # Kill the Phoenix/iex server by freeing its port. The beam process
          # serving that listener IS the iex node, so this stops it cleanly.
          # PHX_PORT is the deterministic port exported in enterShell.
          PHX_PORT="''${PHX_PORT:-$(phx-port)}"
          if [ -n "$PHX_PORT" ]; then
            lsof -tiTCP:"$PHX_PORT" -sTCP:LISTEN 2>/dev/null | xargs -r kill 2>/dev/null || true
          fi

          # Best-effort: also kill by SNAME in case the port lookup is stale.
          if [ -n "''${SNAME:-}" ]; then
            pkill -f -- "--sname ''${SNAME}" 2>/dev/null || true
          fi

          # Stop devenv-managed processes (postgres + process-compose).
          devenv processes down 2>/dev/null || devenv processes stop 2>/dev/null || true

          echo "worktree:teardown complete"

          ${cfg.hooks.post-teardown}
        '';
      };
    };
  };
}
