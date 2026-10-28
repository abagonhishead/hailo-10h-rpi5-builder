#!/usr/bin/env bash
# TAPPAS core: the GStreamer elements for vision pipelines (hailofilter, hailooverlay,
# hailomuxer, ...), the post-processing libraries for detection, pose and segmentation models,
# and the `hailo` Python module for reading results in a pipeline.
. "$(dirname "$0")/lib.sh"
out=$BUILD/tappas-$VERSION
ext=$SRC/tappas/core/open_source      # its header-only dependencies (fetch.sh)
py=$(python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')
step "TAPPAS $VERSION: configure"
reconf=
[ -d "$out" ] && reconf=--reconfigure
run tappas-configure env CC=gcc CXX=g++ meson setup "$out" "$SRC/tappas/core/hailo" $reconf \
    --prefix /usr --buildtype release -Dtarget=all -Dtarget_platform=rpi5 -Dinclude_python=true \
    -Dpython_version="$py" -Dlibargs="-I$STAGE/usr/include/hailo/,-I$STAGE/usr/include/gstreamer-1.0/gst/hailo/" \
    -Dlibxtensor="$ext/xtensor_stack/base" -Dlibcxxopts="$ext/cxxopts" -Dlibrapidjson="$ext/rapidjson" \
    -Dpybind11="$ext/pybind11" -Dlibcatch2="$ext/catch2"
step "TAPPAS: build"
run tappas-build ninja -C "$out" -j"$JOBS"
step "TAPPAS: stage"
run tappas-stage env DESTDIR="$STAGE" meson install -C "$out"
ls "$STAGE/usr/lib/$MULTIARCH/gstreamer-1.0/" | grep -i hailo
