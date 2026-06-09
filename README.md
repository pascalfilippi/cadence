# cadence

A Universal Blue–based KDE bootc image tuned for low-latency PipeWire audio. Built on Aurora-DX, so it inherits KDE Plasma 6, Distrobox, Docker, and Podman.

## Variants

Two images are published from this repo — pick the one that matches your GPU:

| Image | Base | When to use |
|---|---|---|
| `ghcr.io/pascalfilippi/cadence` | `aurora-dx` | Intel iGPU, AMD GPU, or you want to layer your own NVIDIA driver |
| `ghcr.io/pascalfilippi/cadence-nvidia` | `aurora-dx-nvidia-open` | NVIDIA Turing (GTX 16xx, RTX 20xx) or newer — uses the NVIDIA **open kernel modules** |

> **Pre-Turing NVIDIA cards** (GTX 10xx and earlier) aren't supported by the open kernel modules. Use `cadence` (no GPU drivers) and layer the proprietary driver via rpm-ostree.

## What is tuned and installed

- **Kernel arguments** (`/usr/lib/bootc/kargs.d/10-audio-lowlat.toml`): `preempt=full threadirqs`. Turns the stock Fedora kernel's `PREEMPT_DYNAMIC` into full preemption and makes IRQ handlers run as threads, so the audio thread isn't starved by hardware interrupts.
- **PipeWire** (`/etc/pipewire/pipewire.conf.d/10-low-latency.conf`): clock rate 48 kHz, quantum 256 (≈5 ms at 48 kHz), allowed rates 44.1/48/88.2/96 kHz.
- **WirePlumber** (`/etc/wireplumber/wireplumber.conf.d/51-alsa-lowlatency.conf`): mirrors PipeWire's rate config at the ALSA monitor layer.
- **RT scheduling** (`/etc/security/limits.d/95-realtime.conf`): users in the `realtime` group get `rtprio 95`, `memlock unlimited`, `nice -19`. The `realtime` group is created automatically via systemd-sysusers.
- **Sysctl** (`/etc/sysctl.d/90-audio.conf`): lower `vm.swappiness`, larger `fs.inotify.max_user_watches`.
- **Audio utilities**: `qpwgraph` (Qt patchbay), `easyeffects`, `pipx` (so `ujust audio-rt-check` can install `rtcqs` on demand).

Audinux isn't enabled by default. If you want extra Fedora audio packages from there later, run `sudo rpm-ostree -y copr enable ycollet/audinux` on the host.

## What is NOT installed

By design — install via Distrobox or Flatpak:

- DAWs (Ardour, REAPER, Bitwig, Qtractor, …)
- Native Linux VST/LV2 plugins
- Wine, yabridge, and any Windows-VST bridging stack (handled out-of-image)

## Install / rebase

From any bootc system (Aurora, Bazzite, Bluefin, Fedora Atomic), pick one:

```bash
# Non-NVIDIA / AMD / Intel:
sudo bootc switch ghcr.io/pascalfilippi/cadence:latest

# NVIDIA (Turing+):
sudo bootc switch ghcr.io/pascalfilippi/cadence-nvidia:latest

sudo systemctl reboot
```

## Post-install setup (one-time)

1. Add yourself to the `realtime` group so the RT/memlock limits apply, then **log out and back in**:

   ```bash
   ujust audio-join-realtime-group
   ```

   Verify after relogin:
   ```bash
   ulimit -r       # expect 95
   ulimit -l       # expect unlimited
   ```

2. (Optional) Run the realtime diagnostic:
   ```bash
   ujust audio-rt-check
   ```

3. Confirm kernel args took effect:
   ```bash
   cat /proc/cmdline    # should contain `preempt=full threadirqs`
   ```

## Opt-in kernels

The default is the stock Fedora kernel, which is fine for most low-latency audio work once `preempt=full threadirqs` are set. Two opt-in alternatives are available via `ujust`:

| Kernel | Scheduler | Preemption | What you get | Cost |
|---|---|---|---|---|
| **Stock Fedora** (default) | EEVDF | DYNAMIC + `preempt=full` | Good enough for ≤5 ms USB audio | none |
| **kernel-cachyos** | BORE+EEVDF | DYNAMIC | Better desktop responsiveness under load, less audio glitching under CPU pressure | NVIDIA akmod rebuilds on next boot; needs x86-64-v3 CPU |
| **kernel-cachyos-rt** | EEVDF | PREEMPT_RT | True hard real-time scheduling | Same akmod cost; rarely needed for guitar monitoring |

```bash
ujust audio-install-cachyos        # BORE+EEVDF, PREEMPT_DYNAMIC
ujust audio-install-cachyos-rt     # PREEMPT_RT
```

Both prompt before making changes and require a reboot.

## Day-to-day `ujust` recipes

- `ujust audio-set-quantum 128` — drop the PipeWire quantum to 128 samples (≈2.7 ms at 48 kHz) for guitar monitoring. Use higher (256/512) for mixing.
- `ujust audio-reset-quantum` — reset to the file defaults.
- `ujust audio-rt-check` — run `rtcqs`.
- `ujust audio-install-reaper` — set up REAPER in user home directory.

## Building locally

Requires `just` and `podman`:

```bash
just build cadence          # build the non-NVIDIA variant (default)
just build-nvidia           # build the NVIDIA-open variant
just build-qcow2            # build a VM disk image
just run-vm-qcow2           # boot the VM image
just lint                   # shellcheck on build.sh
```

## Verifying the image works

After install + reboot:

| Check | Command | Expected |
|---|---|---|
| KDE Plasma | `plasmashell --version` | Plasma 6.x |
| Kernel args | `cat /proc/cmdline` | contains `preempt=full threadirqs` |
| `realtime` group exists | `getent group realtime` | returns a group line |
| RT diagnostic | `rtcqs` | green/passing |
| RT limits after relogin | `ulimit -r` | 95 |
| PipeWire quantum | `pw-top` | quantum 256 at 48 kHz |
| NVIDIA | `nvidia-smi` | reports your GPU |
| Distrobox | `distrobox create -i fedora-toolbox:43 test` | succeeds |
| Docker | `docker run hello-world` | runs |
| Podman | `podman run hello-world` | runs |

Audio bar (manual, hardware-dependent): with a USB class-compliant interface, `jack_iodelay` round trip ≤ 5 ms at 128/48000.

## Why this image exists

To merge guitar practice, gaming, and dev work into one OS, so reboots don't get between picking up the instrument and using the computer. Aurora-DX handles KDE/Distrobox/Docker/Podman (the `-nvidia` variant also handles NVIDIA); this image adds the audio-latency layer that makes Linux guitar amp-sims actually viable. Windows-VST bridging is handled out-of-image via Distrobox.
