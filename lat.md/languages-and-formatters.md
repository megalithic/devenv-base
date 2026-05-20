# Languages and formatters

Enables Nix and shell by default. Formats on every commit via treefmt. Disable languages with `devenv-base.languages.enable = false` or treefmt with `devenv-base.treefmt.enable = false`.

## Languages

`modules/languages/default.nix` enables `languages.nix` and `languages.shell`.

## Formatters

`modules/treefmt/default.nix` imports [treefmt-nix](https://github.com/numtide/treefmt-nix) and enables three formatters:

- [nixfmt](https://github.com/NixOS/nixfmt) — Nix
- [prettier](https://github.com/prettier/prettier) — JS/TS/JSON/YAML/Markdown
- [shfmt](https://github.com/mvdan/sh) — shell

Lock files (`*.lock`, `*.lockb`, `package-lock.json`, `pnpm-lock.yaml`) and `.devenv*` are excluded from formatting.

## Configuration

`devenv-base.treefmt` — submodule with freeform attrs passed to treefmt-nix, plus `enable` for opting out. Add formatters or change excludes:

```nix
devenv-base.treefmt = {
  settings.global.excludes = [ "some/generated/file" ];
  programs = {
    fish_indent.enable = true;
    black.enable = true;
  };
};
```

## Format task

`devenv tasks run nix:format` runs `treefmt -v` outside of git hooks.
