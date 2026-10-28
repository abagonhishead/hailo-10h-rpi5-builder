#!/usr/bin/env bash
# Download a compiled model (.hef) for this Hailo release from Hailo's public model store, into
# models/<version>/. For example: scripts/get-model.sh Whisper-Small
. "$(dirname "$0")/lib.sh"
[ $# -ge 1 ] || { echo "Usage: $0 <model> [<model> ...]   e.g. Whisper-Small, Whisper-Base" >&2; exit 2; }
dir=$ROOT/models/$VERSION
mkdir -p "$dir"
for m in "$@"; do
    step "$m"
    curl -fL --progress-bar -o "$dir/$m.hef.part" "$MODELS_URL/$m.hef" && mv "$dir/$m.hef.part" "$dir/$m.hef"
    echo "$dir/$m.hef"
done
