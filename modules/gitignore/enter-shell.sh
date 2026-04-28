#!/usr/bin/env bash
set -euo pipefail

gitignore_file="$1"

if ! cmp -s "$gitignore_file" "$DEVENV_ROOT/.gitignore"; then
  install -m 444 "$gitignore_file" "$DEVENV_ROOT/.gitignore"
fi
