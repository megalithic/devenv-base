#!/usr/bin/env bash
set -euo pipefail

# Replace a symlink, cleaning up macOS " 2", " 3" duplicates first.
# Only removes symlinks — never touches regular files.
safe_ln() {
  local src="$1" dest="$2"
  local dir base name ext

  dir="$(dirname "$dest")"
  base="$(basename "$dest")"

  # Remove target if it's a symlink
  [ -L "$dest" ] && rm "$dest"

  # Build name/ext for duplicate pattern
  if [[ $base == *.* ]]; then
    name="${base%.*}"
    ext=".${base##*.}"
  else
    name="$base"
    ext=""
  fi

  # Remove "name N.ext" duplicate symlinks in same dir
  find "$dir" -maxdepth 1 -type l \
    \( -name "${name} ${ext}" -o -name "${name} [0-9]*${ext}" \) \
    -delete 2>/dev/null || true

  ln -s "$src" "$dest"
}

# Remove a path only if it's a symlink. Also clears " 2"/" 3" duplicates.
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
skill_dest="$root/.pi/skills/lat-md/SKILL.md"
ext_dest="$root/.pi/extensions/lat.ts"

if [ "$mode" = "enable" ]; then
  skill_file="$2"
  extension_file="$3"
  mkdir -p "$root/.pi/skills/lat-md"
  safe_ln "$skill_file" "$skill_dest"
  mkdir -p "$root/.pi/extensions"
  safe_ln "$extension_file" "$ext_dest"
else
  safe_rm_link "$skill_dest"
  safe_rm_link "$ext_dest"
  # Drop empty skills dir if we created it
  rmdir "$root/.pi/skills/lat-md" 2>/dev/null || true
fi
