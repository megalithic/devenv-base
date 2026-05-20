#!/usr/bin/env bash
set -euo pipefail

# Replace a symlink, cleaning up macOS " 2", " 3" duplicates first.
# Only removes symlinks — never touches regular files.
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
root="${DEVENV_ROOT:-$PWD}"
mcp_dest="$root/.pi/mcp.json"
hook_dest="$root/.pi/extensions/post-edit-hook.ts"

if [ "$mode" = "enable" ]; then
  mcp_config="$2"
  post_edit_hook="${3:-}"
  mkdir -p "$root/.pi/extensions"
  safe_ln "$mcp_config" "$mcp_dest"
  if [ -n "$post_edit_hook" ]; then
    safe_ln "$post_edit_hook" "$hook_dest"
  else
    safe_rm_link "$hook_dest"
  fi
else
  safe_rm_link "$mcp_dest"
  safe_rm_link "$hook_dest"
fi
