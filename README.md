# hailo-h10-rpi5

Build Hailo's current software for the **Raspberry Pi AI HAT+ 2 (Hailo-10H) on a Raspberry Pi 5**
from Hailo's public sources: the PCIe driver, the firmware, HailoRT, the Python bindings,
hailo-ollama and TAPPAS. No Hailo Developer Zone account is needed.

Raspberry Pi's apt repository ships HailoRT 5.1.1. Hailo has released newer versions since, but
only as source on GitHub and as binaries behind a Developer Zone login. These scripts build the
release named in `versions.env` (5.4.0 at the moment) and install it in place of Raspberry Pi's
packages.

This repository contains only build scripts. Hailo's code, firmware and models are downloaded
from Hailo when you run them, and stay under Hailo's licences.

## What you get

| Piece | What it is | Built from |
|---|---|---|
| `hailo1x_pci` | The PCIe driver, installed with DKMS so it's rebuilt for new kernels | [hailort-drivers](https://github.com/hailo-ai/hailort-drivers) |
| Firmware | What the Hailo-10H boots, loaded by the driver | Hailo's public download (you're asked to accept its licence) |
| HailoRT | `libhailort`, `hailortcli`, the GStreamer plugin (`hailonet`) | [hailort](https://github.com/hailo-ai/hailort) |
| `hailo_platform` | HailoRT for Python, including `hailo_platform.genai` (Whisper speech-to-text, language models, vision-language models) | hailort |
| hailo-ollama | An Ollama-compatible server for language models on the Hailo-10H | [hailo_model_zoo_genai](https://github.com/hailo-ai/hailo_model_zoo_genai) |
| TAPPAS core | GStreamer elements for vision pipelines (`hailofilter`, `hailooverlay`, `hailocropper`, `hailotracker`, ...), post-processing for detection, pose and segmentation models, and the `hailo` Python module for reading results | [tappas](https://github.com/hailo-ai/tappas) |

## What you need

- A Raspberry Pi 5 with the AI HAT+ 2 (Hailo-10H). Nothing else is supported.
- 64-bit Raspberry Pi OS based on Debian 13 (trixie). It has been tested with kernel
  6.18.50+rpt-rpi-2712.
- About 4 GB of free disk space for the sources and the build, and an internet connection.
- About 20 to 25 minutes: HailoRT and its Python bindings take about 13, hailo-ollama 3 and
  TAPPAS 3.

The HAT+ is detected and PCIe is switched on automatically. Optionally, add
`dtparam=pciex1_gen=3` to `/boot/firmware/config.txt` for PCIe Gen 3, as Raspberry Pi recommends
for the AI HATs.

## Build and install

```sh
git clone https://github.com/abagonhishead/hailo-h10-rpi5 && cd hailo-h10-rpi5
sudo ./scripts/deps.sh        # build tools and libraries, from Raspberry Pi OS
./build.sh                    # fetch and build everything into build/stage: changes nothing yet
sudo ./install.sh             # install it (replacing Raspberry Pi's Hailo packages, if any)
                              # HAILO_GROUP=<group>: who may use the device (default: hailo)
sudo usermod -aG hailo $USER  # then log out and in again
hailortcli fw-control identify
```

The last command should report the firmware version and `HAILO10H`.

`./build.sh` shows Hailo's firmware licence and asks you to accept it before downloading the
firmware. To skip the question, set `ACCEPT_HAILO_FIRMWARE_EULA=yes` (once you've read it), or
use firmware you already have for the same version with
`FIRMWARE_FROM=/lib/firmware/hailo/hailo10h ./build.sh`.

`./build.sh --no-tappas` or `--no-ollama` leaves those pieces out. The builds use every CPU core;
`JOBS=2 ./build.sh` uses fewer, if a Pi with little memory runs short. Each step logs to `logs/`,
and when one fails it shows the end of its log.

### What the install does

`install.sh` asks before it changes anything, and backs up the current state (package list,
firmware) to `/var/backups/hailo-h10-rpi5/`. The driver is reloaded, so nothing may have the
Hailo-10H open: it stops hailo-ollama itself, and lists anything else using the device (your own
programs, a `hailortcli monitor`) for you to stop first. Then it:

1. Removes Raspberry Pi's Hailo packages if they're installed (`hailo-h10-all` and the packages
   it pulls in, plus the Hailo-8 runtime `hailort`, which apt otherwise reaches for), and pins
   them in `/etc/apt/preferences.d/hailo-h10-rpi5` so apt doesn't put them back.
2. Installs the driver with DKMS, and the firmware in `/lib/firmware/hailo/hailo10h`.
3. Copies HailoRT, hailo-ollama and TAPPAS into `/usr`, and `hailo_platform` into the system
   python3.
4. Lets the `hailo` group use the device (a udev rule), and sets up the `hailo-ollama` user and
   service. The service isn't started unless it was running before.
5. Resets the Hailo-10H so that it boots the new firmware, without rebooting the Pi.

It records every file it installs in `/var/lib/hailo-h10-rpi5/installed-files.txt`.
`sudo ./uninstall.sh` removes them again. After that, `sudo rm
/etc/apt/preferences.d/hailo-h10-rpi5 && sudo apt install hailo-h10-all` goes back to Raspberry
Pi's packages, if the pin file is still there.

### Another release

Set `HAILO_VERSION` in `versions.env`, then build and install again. The scripts expect each of
Hailo's repositories to have a `v<version>` tag, and the firmware and models to be at the same
download paths. Hailo has kept to that so far, but check the release notes.

## Using it

**HailoRT from the command line:**

```sh
hailortcli fw-control identify     # the device and its firmware
hailortcli scan
```

**Whisper speech-to-text in Python.** Download a model first, e.g. `scripts/get-model.sh
Whisper-Small` (or `Whisper-Base`, faster and less accurate). It's saved in `models/<version>/`.

```python
import numpy as np
from hailo_platform import VDevice
from hailo_platform.genai import Speech2Text, Speech2TextTask

vdevice = VDevice()
whisper = Speech2Text(vdevice, "models/5.4.0/Whisper-Small.hef")
audio = np.zeros(16000, dtype=np.float32)   # 16 kHz mono, float32 in [-1, 1]
print(whisper.generate_all_text(audio, task=Speech2TextTask.TRANSCRIBE, language="en"))
```

On the Hailo-10H, Whisper-Small takes about 1 to 2 seconds for a short sentence, and
Whisper-Base 0.4 to 0.8 seconds. Either way it uses almost no CPU.

**Language models with hailo-ollama:**

```sh
sudo systemctl enable --now hailo-ollama
curl -s http://localhost:8000/hailo/v1/list                                # models you can pull
curl -s http://localhost:8000/api/pull -d '{"model": "qwen2.5:1.5b", "stream": false}'
curl -s http://localhost:8000/api/chat -d '{"model": "qwen2.5:1.5b", "messages": [{"role": "user", "content": "Hello"}]}'
```

It speaks the Ollama API on port 8000, so tools that work with Ollama can use it.

**Vision pipelines with TAPPAS:**

```sh
gst-inspect-1.0 hailo                # HailoRT's hailonet element
gst-inspect-1.0 hailotools           # TAPPAS's elements
python3 -c "import hailo"            # the module for reading results in a pipeline
```

The post-processing libraries are in `/usr/lib/aarch64-linux-gnu/hailo/tappas/post_processes`.
For example pipelines and apps, see Hailo's
[hailo-rpi5-examples](https://github.com/hailo-ai/hailo-rpi5-examples) and
[hailo-apps](https://github.com/hailo-ai/hailo-apps). They need models compiled for the
Hailo-10H.

### Sharing the Hailo-10H between programs

The Hailo-10H serves one group of processes at a time. Once one program has it open, a second
one gets `HAILO_OUT_OF_PHYSICAL_DEVICES`, unless both open it in the same group:

```python
params = VDevice.create_params()
params.group_id = "SHARED"
vdevice = VDevice(params)
```

The hailo-ollama service installed here already uses the group `SHARED`
(`HAILO_OLLAMA_VDEVICE_GROUP_ID`), so your own programs can use the device alongside it if they
use `SHARED` too.

## Notes

[docs/notes.md](docs/notes.md) has what we found while getting this working: device names, the
firmware update, the GStreamer plugin path, and Raspberry Pi's packages.

## Licence

The scripts in this repository are under the [MPL-2.0](LICENSE). The software they download is
Hailo's, under Hailo's licences: HailoRT and hailo_model_zoo_genai are MIT, the PCIe driver
GPL-2.0, TAPPAS LGPL-2.1, and the firmware is under Hailo's firmware licence
(`hailort/hailo_firmware_eula` in the HailoRT sources), which only allows using it with Hailo
hardware you've bought. Models downloaded with `get-model.sh` come from Hailo's public model
store, under their own terms. This project isn't affiliated with Hailo or Raspberry Pi.
