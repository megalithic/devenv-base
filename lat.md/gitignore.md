# Gitignore

Generates a locked `.gitignore` on shell entry. Configured in `modules/gitignore/default.nix`, written by `modules/gitignore/enter-shell.sh`.

## Base entries

The generated ignore list covers devenv, pi, local override files, and `result`. It includes `lat.md/.cache/` only when `devenv-base.lat-md.enable = true`.

## Lock mechanism

The file is set to mode 444. This prevents accidental edits — the gitignore is managed by the module, not by hand.

## Options

`devenv-base.gitignore.enable` — enable managed `.gitignore`. Defaults to `true`.

Disable it when the repo owns `.gitignore` as a team-managed file:

```nix
devenv-base.gitignore.enable = false;
```

If `.gitignore` was already generated read-only, run `chmod u+w .gitignore` once after disabling.

`devenv-base.gitignore.extraEntries` — list of patterns appended after the base entries.

```nix
devenv-base.gitignore.extraEntries = [ "node_modules" "*.pyc" ];
```
