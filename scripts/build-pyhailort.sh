#!/usr/bin/env bash
# The hailo_platform Python package (pyhailort) as a wheel for the system python3 (about 90 s).
. "$(dirname "$0")/lib.sh"
venv=$BUILD/pybuild-venv
[ -x "$venv/bin/pip" ] || python3 -m venv "$venv"
run pyhailort-tools "$venv/bin/pip" install "scikit-build-core>=0.10" "pybind11>=2.13.6,<3" wheel
mkdir -p "$BUILD/wheels"
step "hailo_platform wheel"
run pyhailort-build env CMAKE_ARGS="-DLIBHAILORT_PATH=$STAGE/usr/lib/$MULTIARCH/libhailort.so.$VERSION -DHAILORT_INCLUDE_DIR=$STAGE/usr/include" \
    "$venv/bin/pip" wheel "$SRC/hailort/hailort/libhailort/bindings/python/platform" \
    -w "$BUILD/wheels" --no-deps --no-build-isolation
ls "$BUILD"/wheels/hailort-"$VERSION"-*.whl
