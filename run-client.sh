#!/bin/bash
# Launch the Meridian 59 client under Proton.
#
# Usage:
#   ./run-client.sh
#   ./run-client.sh /U:username /W:password /H:localhost /P:5959
#
# Proton is auto-detected from common Steam install locations, or set
# PROTON_PATH to override. A Proton prefix is created in run/localclient/pfx/.
#
# The client expects its working directory to be run/localclient/ where
# meridian.exe, OpenAL32.dll, and the resource/ subdirectory reside.
# Game assets (BGF, ROO, WAV files) must also be present there.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="${SCRIPT_DIR}/run/localclient"
CLIENT_EXE="${CLIENT_DIR}/meridian.exe"

if [ ! -f "${CLIENT_EXE}" ]; then
    echo "Error: ${CLIENT_EXE} not found."
    echo "Build first: cmake -B build && cmake --build build -j\$(nproc)"
    exit 1
fi

find_proton() {
    local search_dirs=(
        "${HOME}/.local/share/Steam/compatibilitytools.d"
        "${HOME}/.steam/steam/compatibilitytools.d"
        "${HOME}/.steam/root/compatibilitytools.d"
        "${HOME}/.local/share/Steam/steamapps/common"
        "${HOME}/.steam/steam/steamapps/common"
    )
    for dir in "${search_dirs[@]}"; do
        if [ -d "${dir}" ]; then
            for pattern in "Proton-GE*" "Proton*Experimental" "Proton*"; do
                local match
                match="$(find "${dir}" -maxdepth 1 -name "${pattern}" -type d 2>/dev/null | sort -V | tail -1)"
                if [ -n "${match}" ] && [ -f "${match}/proton" ]; then
                    echo "${match}/proton"
                    return 0
                fi
            done
        fi
    done
    return 1
}

if [ -n "${PROTON_PATH:-}" ]; then
    PROTON="${PROTON_PATH}"
elif PROTON="$(find_proton)"; then
    :
else
    echo "Error: Proton not found."
    echo "Install Proton via Steam, or set PROTON_PATH=/path/to/proton"
    exit 1
fi

echo "Using Proton: ${PROTON}"

export STEAM_COMPAT_DATA_PATH="${CLIENT_DIR}/pfx"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${HOME}/.local/share/Steam"
mkdir -p "${STEAM_COMPAT_DATA_PATH}"

cd "${CLIENT_DIR}"
exec "${PROTON}" run meridian.exe "$@"
