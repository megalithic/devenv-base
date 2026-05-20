# devenv-base

Shared [devenv](https://devenv.sh) setup. Bundles base languages, formatters, git hooks, neovim config, gitignore management, and AI tooling.

## Prerequisites

- [devenv](https://devenv.sh)

## Install

### 1. Create `devenv.yaml`

**All four inputs are required.** `treefmt-nix` and `git-hooks` are peer dependencies consumed directly by devenv-base.

```yaml
inputs:
  devenv-base:
    url: github:otahontas/devenv-base
    flake: false
  git-hooks:
    url: github:cachix/git-hooks.nix
    inputs:
      nixpkgs:
        follows: nixpkgs
  nixpkgs:
    url: github:cachix/devenv-nixpkgs/rolling
  treefmt-nix:
    url: github:numtide/treefmt-nix
    flake: false
imports:
  - devenv-base
```

### 2. Create `devenv.nix`

Uses all defaults:

```nix
_: {}
```

### 3. Enter the shell

```sh
devenv shell
```

## What's included

See `lat.md/` for full documentation. Briefly:

- **Languages** — Nix, shell, Lua
- **Formatters** — nixfmt, prettier, shfmt, stylua (via treefmt, runs on commit)
- **Git hooks** — check-merge-conflicts, deadnix, detect-private-keys, shellcheck, typos, commitlint, gitleaks, statix
- **Neovim** — `.nvim.lua` with LSPs for Nix, shell, and Lua
- **Gitignore** — locked `.gitignore` managed by the module
- **AI tooling** — pi MCP server, post-edit hook, AGENTS.md, lat.md extension
- **Tickets** — `tk` CLI from [wedow/ticket](https://github.com/wedow/ticket)
- **GitHub Actions** — reusable setup-devenv action, weekly lock file update

## Configuration

All options live under the `devenv-base` namespace. Most modules have `devenv-base.<module>.enable`, defaulting to `true`, so consumers can opt out of base behavior. See `lat.md/` for details on extending languages, formatters, LSPs, gitignore entries, and more.
