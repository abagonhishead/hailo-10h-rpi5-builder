# Notes

What we found while building HailoRT 5.4.0 for the Hailo-10H on a Raspberry Pi 5.

## Raspberry Pi's packages

- Raspberry Pi's apt repository has shipped HailoRT 5.1.1 (`hailo-h10-all`) since November
  2025. A 5.2.0 model-zoo package reached it in May 2026 without its matching runtime, and broke
  upgrades ([hailo-ai/hailo-rpi5-examples#195](https://github.com/hailo-ai/hailo-rpi5-examples/issues/195)).
- `rpicam-apps-hailo-postprocess` depends on `h10-hailort | hailort`. When `h10-hailort` is
  removed, apt installs `hailort`, the Hailo-8 runtime (4.x), unless it's blocked. That's why the
  install pins both.
- `hailo-gen-ai-model-zoo` 5.1.1's postrm deletes the models hailo-ollama has downloaded. Pull
  them again after switching.

## The driver and firmware

- The 5.4.0 driver names the device `/dev/h1x-N`, in udev subsystem `hailo1x`. 5.1.1 used
  `/dev/hailoN` in `hailo_chardev`, so old udev rules no longer match.
- Nothing is flashed: the Hailo-10H boots firmware that the driver supplies from
  `/lib/firmware/hailo/hailo10h` (u-boot, `fitImage`, `image-fs`). It keeps running the old
  firmware until it's reset, and a 5.4.0 driver then logs `Mismatch Driver version ... pci_ep
  driver 5:1:1`. Writing 1 to `/sys/bus/pci/devices/<address>/reset` with the driver unloaded
  makes it boot the new files without rebooting the Pi. `install.sh` does this.
- The firmware downloads without a login, from Hailo's public S3 bucket.

## Building

- `HAILO_BUILD_OLLAMA` in HailoRT's CMake is declared but unused. hailo-ollama is built from
  `hailo_model_zoo_genai`, with `find_package(HailoRT 5)` pointed at the staged HailoRT.
- HailoRT installs its GStreamer plugin to `lib/aarch64-linux-gnu/aarch64-linux-gnu/gstreamer-1.0`
  (the multiarch directory twice). It belongs in `lib/aarch64-linux-gnu/gstreamer-1.0`, and
  `build-hailort.sh` moves it.
- HailoRT's CMake downloads some of its dependencies from GitHub while configuring, so the build
  needs internet access.
- Never `cp -a` a staged tree over `/usr`: it copies the builder's ownership and permissions
  onto system directories. `install.sh` creates directories as root first, then copies files.
- With Debian's pip, `--prefix /usr/local` installs to `/usr/local/local/...`. Root pip without
  `--prefix` already uses `/usr/local/lib/python3.X/dist-packages`.

## Using the device

- On a discrete Hailo-10H, libhailort sends requests to `hailort_server`, which runs on the
  accelerator and serves one VDevice group at a time. A second process gets
  `HAILO_OUT_OF_PHYSICAL_DEVICES` (74), unless both open their VDevice with the same `group_id`
  (the default is `UNIQUE`). For hailo-ollama, set `HAILO_OLLAMA_VDEVICE_GROUP_ID`.
  `multi_process_service` is for the Hailo-15, not this.
- Compiled models (`.hef`) are specific to a chip and a HailoRT version: use ones built for the
  Hailo-10H and the release you installed.
