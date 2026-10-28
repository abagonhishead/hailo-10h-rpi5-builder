#!/usr/bin/env bash
# hailo-ollama, Hailo's Ollama-compatible server for language models, against the staged
# HailoRT (about 3 minutes).
. "$(dirname "$0")/lib.sh"
out=$BUILD/hailo-ollama-$VERSION
step "hailo-ollama $VERSION: configure"
run hailo-ollama-configure cmake -S "$SRC/hailo_model_zoo_genai" -B "$out" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_PREFIX_PATH="$STAGE/usr" \
    -DHailoRT_DIR="$STAGE/usr/lib/$MULTIARCH/cmake/HailoRT"
step "hailo-ollama: build"
run hailo-ollama-build cmake --build "$out" -j"$JOBS"
step "hailo-ollama: stage"
run hailo-ollama-stage env DESTDIR="$STAGE" cmake --install "$out"
ls "$STAGE/usr/bin/hailo-ollama"
