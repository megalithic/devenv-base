# Neovim

Generates `.nvim.lua` with LSP setup. Configured in `modules/nvim/default.nix`.

## Base LSPs

nixd (Nix), bashls (shell).

## Options

Three options control the base config.

- `devenv-base.nvim.enable` — generate `.nvim.lua`. Defaults to `true`.
- `devenv-base.nvim.extraLsps` — list of LSP server names added on top of the base set.
- `devenv-base.nvim.extraConfig` — string appended after LSP setup.

```nix
devenv-base.nvim.extraLsps = [ "pyright" "ts_ls" ];
devenv-base.nvim.extraConfig = ''
  vim.opt.tabstop = 4
'';
```

## File generation

The generated `.nvim.lua` is wrapped in `-- ### devenv-base nvim` / `-- ### end` markers. Extra LSPs and config appear after the end marker. This makes the base section distinguishable from consumer additions.
