# devenv-base

Shared [devenv](https://devenv.sh) setup — languages, formatters, git hooks, neovim config, gitignore management, and AI tooling. Consumed by other repos as a flake input.

- [[ai-tooling]] — pi integrations: MCP, post-edit hook, AGENTS.md, lat.md extension, tk
- [[git-hooks]] — pre-commit hooks
- [[github-actions]] — CI/CD setup
- [[gitignore]] — locked gitignore management
- [[languages-and-formatters]] — Nix, shell + treefmt
- [[nvim]] — LSP config generation

## Module system

Each module is a Nix file in `modules/` that declares options under `devenv-base.*` and sets config values. `devenv.nix` at the repo root imports all modules.

Consumer repos reference this flake in `devenv.yaml` and extend options in their own `devenv.nix`.

Most modules expose `devenv-base.<module>.enable`, defaulting to `true`. Set it to `false` to opt out of that module's packages, generated files, shell hooks, tasks, or git hooks.

## Extension pattern

All modules accept options under the `devenv-base` namespace. Consumers override, extend, or disable modules via these options in their own `devenv.nix`.

## Adding a new language

Three steps: enable the language, add a formatter, add an LSP.

```nix
_: {
  # 1. Enable the language
  languages.python.enable = true;

  # 2. Add a formatter
  devenv-base.treefmt.programs.black.enable = true;

  # 3. Add an LSP
  devenv-base.nvim.extraLsps = [ "pyright" ];
}
```

Swap `python`/`black`/`pyright` for your language. See [devenv language options](https://devenv.sh/reference/options/#languages) and [treefmt-nix programs](https://github.com/numtide/treefmt-nix/tree/master/programs).
