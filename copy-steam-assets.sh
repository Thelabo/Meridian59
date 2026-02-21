#!/bin/bash
# Copy Meridian 59 game assets from a Steam installation into run/localclient/
# so the cross-compiled client can find them.
#
# Usage:
#   ./copy-steam-assets.sh                    # auto-detect Steam install
#   ./copy-steam-assets.sh /path/to/Meridian\ 59   # explicit path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="${SCRIPT_DIR}/run/localclient"
RESOURCE_DIR="${CLIENT_DIR}/resource"

BUILT_DLLS="admin.dll char.dll chess.dll dm.dll mailnews.dll merintr.dll"

find_steam_m59() {
    local search_dirs=(
        "${HOME}/.local/share/Steam/steamapps/common/Meridian 59"
        "${HOME}/.steam/steam/steamapps/common/Meridian 59"
        "${HOME}/.steam/root/steamapps/common/Meridian 59"
    )
    for dir in "${search_dirs[@]}"; do
        if [ -d "${dir}/resource" ]; then
            echo "${dir}"
            return 0
        fi
    done
    return 1
}

if [ $# -ge 1 ]; then
    STEAM_M59="$1"
else
    if ! STEAM_M59="$(find_steam_m59)"; then
        echo "Error: Meridian 59 Steam installation not found."
        echo "Usage: $0 /path/to/Meridian\\ 59"
        exit 1
    fi
fi

if [ ! -d "${STEAM_M59}/resource" ]; then
    echo "Error: ${STEAM_M59}/resource not found. Is this a valid Meridian 59 install?"
    exit 1
fi

echo "Steam install: ${STEAM_M59}"
echo "Target:        ${CLIENT_DIR}"
echo ""

mkdir -p "${RESOURCE_DIR}"

# Resource files: BGF, ROO, OGG, BSF, and other non-DLL assets
echo "Copying resource files..."
copied=0
skipped=0
for f in "${STEAM_M59}/resource/"*; do
    [ -f "${f}" ] || continue
    name="$(basename "${f}")"

    # Skip DLLs we build ourselves
    skip=false
    for dll in ${BUILT_DLLS}; do
        if [ "${name,,}" = "${dll}" ]; then
            skip=true
            break
        fi
    done
    if ${skip}; then
        skipped=$((skipped + 1))
        continue
    fi

    cp "${f}" "${RESOURCE_DIR}/"
    copied=$((copied + 1))
done
echo "  ${copied} files copied, ${skipped} built DLLs skipped"

# Top-level data files (font, config template, etc.)
echo "Copying top-level data files..."
top_copied=0
for name in Heidelb1.ttf license.rtf meridian.ini; do
    src="${STEAM_M59}/${name}"
    if [ -f "${src}" ]; then
        cp "${src}" "${CLIENT_DIR}/"
        top_copied=$((top_copied + 1))
    fi
done

# Subdirectories (ads, mail, download, help)
for dir in ads mail download help; do
    src="${STEAM_M59}/${dir}"
    if [ -d "${src}" ]; then
        cp -r "${src}" "${CLIENT_DIR}/"
        top_copied=$((top_copied + 1))
    fi
done
echo "  ${top_copied} top-level items copied"

echo ""
echo "Done. Resource files are in ${RESOURCE_DIR}/"
echo "Run the client with: ./run-client.sh"
