#!/usr/bin/env bash
set -euo pipefail

safe_ln() {
  local src="$1" dest="$2"
  local dir base name ext

  dir="$(dirname "$dest")"
  base="$(basename "$dest")"

  [ -L "$dest" ] && rm "$dest"

  if [[ $base == *.* ]]; then
    name="${base%.*}"
    ext=".${base##*.}"
  else
    name="$base"
    ext=""
  fi

  find "$dir" -maxdepth 1 -type l \
    \( -name "${name} ${ext}" -o -name "${name} [0-9]*${ext}" \) \
    -delete 2>/dev/null || true

  ln -s "$src" "$dest"
}

safe_rm_link() {
  local dest="$1"
  local dir base name ext

  [ -L "$dest" ] && rm "$dest"

  dir="$(dirname "$dest")"
  base="$(basename "$dest")"
  if [[ $base == *.* ]]; then
    name="${base%.*}"
    ext=".${base##*.}"
  else
    name="$base"
    ext=""
  fi
  find "$dir" -maxdepth 1 -type l \
    \( -name "${name} ${ext}" -o -name "${name} [0-9]*${ext}" \) \
    -delete 2>/dev/null || true
}

mode="$1"
dest="${DEVENV_ROOT}/.pi/agent/AGENTS.md"

if [ "$mode" = "enable" ]; then
  agents_md_file="$2"
  mkdir -p "${DEVENV_ROOT}/.pi/agent"
  safe_ln "$agents_md_file" "$dest"
else
  safe_rm_link "$dest"
fi
