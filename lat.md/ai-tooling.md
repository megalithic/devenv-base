# AI tooling

Sets up pi (coding agent) integrations: MCP server, post-edit hook, AGENTS.md, and lat.md extension.

## Symlink cleanup

Each `enter-shell.sh` uses `safe_ln` instead of bare `ln -sfn`. Before creating a symlink, it removes the old one and any macOS " 2", " 3" duplicates (e.g., `AGENTS 2.md`).

The `ai`, `agents-md`, and `lat-md` modules run `enter-shell.sh` unconditionally with an `enable` or `disable` mode argument. In `disable` mode the script calls `safe_rm_link` to remove the managed symlinks under `.pi/`. This guarantees that toggling `devenv-base.<module>.enable` off cleans up prior state, so pi does not load stale extensions, skills, or agent files for disabled modules.

## MCP server

`modules/ai/default.nix` symlinks `modules/ai/mcp.json` to `.pi/mcp.json` and `post-edit-hook.ts` to `.pi/extensions/post-edit-hook.ts` via `enter-shell.sh`.

The default server is `mcp.devenv.sh` (HTTP). Consumers add servers via `devenv-base.ai.mcp.extraServers`. Disable all AI tooling with `devenv-base.ai.enable = false`.

Claude Code is force-disabled only when `devenv-base.ai.enable` is true.

## Post-edit hook

`modules/ai/post-edit-hook.ts` is a pi extension that runs `prek` on files after any `edit` or `write` tool call. On failure, injects the failing hook names into the tool result so the LLM can fix issues before committing.

Invokes prek directly via `.devenv/profile/bin/prek` (avoids devenv shell overhead), and reads prek results from stdout (where prek writes them).

## AGENTS.md

`modules/agents-md/default.nix` writes `.pi/agent/AGENTS.md` via `enter-shell.sh`.

Contains base agent instructions for devenv, tickets, and lat.md workflow. Consumers append entries via `devenv-base.agents-md.extraEntries`, disable the file with `devenv-base.agents-md.enable = false`, or omit the ticket section with `devenv-base.agents-md.includeTk = false`.

Generated AGENTS.md omits the ticket section when `devenv-base.tk.enable = false` and omits the lat.md section when `devenv-base.lat-md.enable = false`, so agents do not follow instructions for disabled tools.

## lat.md extension

`modules/lat-md/default.nix` installs the `lat` CLI (v0.11.0) and symlinks two files into `.pi/` via `enter-shell.sh`.

Its package patch lets `LAT_LLM_BASE_URL`, `LAT_LLM_MODEL`, and `LAT_LLM_DIMENSIONS` override built-in provider detection for OpenAI-compatible embedding endpoints. It also rejects `sk-or-*` OpenRouter keys before lat.md's broad `sk-*` OpenAI branch can send them to `api.openai.com` and fail with a misleading 401.

Disable it with `devenv-base.lat-md.enable = false`; the gitignore module then omits `lat.md/.cache/`.

- `modules/lat-md/SKILL.md` → `.pi/skills/lat-md/SKILL.md` — authoring guide for lat.md files
- `modules/lat-md/lat.ts` → `.pi/extensions/lat.ts` — pi extension that registers lat tools (`lat_search`, `lat_section`, `lat_locate`, `lat_check`, `lat_expand`, `lat_refs`) and injects a once-per-session pre-work reminder and post-work `lat check`. Hooks are gated: `/lat on|off|status` toggles them per session, the model-callable `lat_hooks` tool lets skills toggle them (e.g. grill-me disables hooks during interviews and re-enables after), `LAT_HOOKS=off` starts them disabled, the `agent_end` check only fires when the session itself edited files (via `edit`/`write` tool calls), and the git-diff sync nag compares against a startup baseline so pre-existing dirty-worktree changes never count. It runs `${HOME}/.pi/agent/bin/lat` by default (or `LAT_BIN` when set) so stale PATH entries do not select an unpatched lat package.

## Ticket tool

`modules/tk/default.nix` installs `tk` (v0.3.2, patched) from [wedow/ticket](https://github.com/wedow/ticket). Provides CLI ticket and task management. Disable it with `devenv-base.tk.enable = false`.
