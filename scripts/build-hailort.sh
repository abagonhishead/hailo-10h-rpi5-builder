#!/usr/bin/env bash
# HailoRT: libhailort, hailortcli and the GStreamer plugin (about 11 minutes on a Pi 5).
. "$(dirname "$0")/lib.sh"
out=$BUILD/hailort-$VERSION
step "HailoRT $VERSION: configure"
run hailort-configure cmake -S "$SRC/hailort" -B "$out" -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr -DHAILO_BUILD_GSTREAMER=ON
step "HailoRT: build"
run hailort-build cmake --build "$out" -j"$JOBS"
step "HailoRT: stage"
run hailort-stage env DESTDIR="$STAGE" cmake --install "$out"
# Upstream installs the GStreamer plugin under a doubled multiarch path; put it where GStreamer looks
bad=$STAGE/usr/lib/$MULTIARCH/$MULTIARCH/gstreamer-1.0
if [ -d "$bad" ]; then
    mkdir -p "$STAGE/usr/lib/$MULTIARCH/gstreamer-1.0"
    mv "$bad"/* "$STAGE/usr/lib/$MULTIARCH/gstreamer-1.0/"
    rm -rf "$STAGE/usr/lib/$MULTIARCH/$MULTIARCH"
fi
ls "$STAGE/usr/bin/hailortcli" "$STAGE/usr/lib/$MULTIARCH/libhailort.so.$VERSION"
