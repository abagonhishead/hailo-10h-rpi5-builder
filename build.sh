#!/usr/bin/env bash
# Fetch and build the whole stack into build/stage. Changes nothing on the system: install.sh
# does that. Run scripts/deps.sh (as root) first, and accept Hailo's firmware licence by setting
# ACCEPT_HAILO_FIRMWARE_EULA=yes yourself.
#   ./build.sh                  everything
#   ./build.sh --no-tappas      skip TAPPAS (the vision pipelines)
#   ./build.sh --no-ollama      skip hailo-ollama
. "$(dirname "$0")/scripts/lib.sh"
check_pi5
require_eula      # before anything's downloaded
tappas=1 ollama=1
for a in "$@"; do
    case $a in
        --no-tappas) tappas=0 ;;
        --no-ollama) ollama=0 ;;
        *) echo "Unknown option $a" >&2; exit 2 ;;
    esac
done
"$ROOT/scripts/fetch.sh"
rm -rf "$STAGE"
"$ROOT/scripts/build-hailort.sh"
"$ROOT/scripts/build-pyhailort.sh"
[ $ollama = 1 ] && "$ROOT/scripts/build-hailo-ollama.sh"
[ $tappas = 1 ] && "$ROOT/scripts/build-tappas.sh"
step "Built. Install with: sudo ./install.sh"
