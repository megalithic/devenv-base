# AI tooling

Sets up pi (coding agent) integrations: MCP server, post-edit hook, AGENTS.md, and lat.md extension.

## Symlink cleanup

Each `enter-shell.sh` uses `safe_ln` instead of bare `ln -sfn`. Before creating a symlink, it removes the old one and any macOS " 2", " 3" duplicates (e.g., `AGENTS 2.md`).

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

`modules/lat-md/default.nix` installs the `lat` CLI (v0.11.0) and symlinks two files into `.pi/` via `enter-shell.sh`. Disable it with `devenv-base.lat-md.enable = false`.

- `modules/lat-md/SKILL.md` → `.pi/skills/lat-md/SKILL.md` — authoring guide for lat.md files
- `modules/lat-md/lat.ts` → `.pi/extensions/lat.ts` — pi extension that registers lat tools (`lat_search`, `lat_section`, `lat_locate`, `lat_check`, `lat_expand`, `lat_refs`) and injects a pre-work reminder and post-work `lat check`.

## Ticket tool

`modules/tk/default.nix` installs `tk` (v0.3.2, patched) from [wedow/ticket](https://github.com/wedow/ticket). Provides CLI ticket and task management. Disable it with `devenv-base.tk.enable = false`.
