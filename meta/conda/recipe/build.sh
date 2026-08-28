#!/usr/bin/env bash
set -euo pipefail

# Install the staged payload into the prefix, plus a launcher on PATH.
#
# The payload goes under `libexec` rather than being merged into the prefix's own
# `bin`/`lib`/`share`: it is a complete Julia installation with its own copies of
# common library names, and merging it would have it collide with, or silently
# shadow, whatever else is installed in the same environment.

PAYLOAD_DEST="${PREFIX}/libexec/scibmad"

mkdir -p "${PAYLOAD_DEST}"
# `cp -a` preserves the executable bits and symlinks inside Julia's artifacts; a
# plain `cp -r` produces a tree that cannot run.
cp -a "${SRC_DIR}/payload/." "${PAYLOAD_DEST}/"

# Defensive, and cheap. A freshly staged payload has writable directories and about
# 35,000 read-only files (Julia unpacks artifacts read-only), which is fine: removing
# a file needs write permission on its directory, not on the file, so `conda remove`
# copes. What it does not cope with is read-only *directories* -- it fails partway
# through with "Permission denied" and leaves a half-removed environment behind.
#
# The staged payload has none, but a payload copied out of an installed macOS app
# does: that install applies `chmod -R a-w` to keep its code signature intact, and
# `cp -a` carries the bits across. Nothing here depends on any of it being read-only
# -- signing was a DMG concern and a conda package is not signed -- so normalise.
# Group and other bits are left alone.
chmod -R u+w "${PAYLOAD_DEST}"

mkdir -p "${PREFIX}/bin"
cat > "${PREFIX}/bin/scibmad" <<'LAUNCHER'
#!/bin/sh
# Launcher for the SciBmad distribution.
#
# Resolves the prefix from this script's own location rather than from CONDA_PREFIX,
# so that it works when called by absolute path from outside an activated
# environment.
self="$0"
# Follow symlinks: conda may link this into an environment's bin.
while [ -L "$self" ]; do
    link=$(readlink "$self")
    case "$link" in
        /*) self="$link" ;;
        *)  self="$(dirname "$self")/$link" ;;
    esac
done
PREFIX="$(cd "$(dirname "$self")/.." && pwd)"

# The payload is staged with RUNTIME_MODE=MIN, under which AppEnv takes the user
# depot from USER_DATA. It has to be set, and set to somewhere persistent: unset,
# AppEnv falls back to a fresh temporary directory and anything the user installs
# with Pkg is gone by the next session.
#
# It deliberately does not live in the prefix. Environments get removed and rebuilt,
# may be read-only, and may be shared between users; a user's own packages should
# outlive any of that.
if [ -z "${USER_DATA:-}" ]; then
    USER_DATA="${XDG_DATA_HOME:-$HOME/.local/share}/scibmad"
fi
mkdir -p "$USER_DATA"
export USER_DATA

exec "$PREFIX/libexec/scibmad/bin/julia" "$@"
LAUNCHER

chmod +x "${PREFIX}/bin/scibmad"
