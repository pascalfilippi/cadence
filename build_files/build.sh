#!/bin/bash
set -ouex pipefail

# ---------- Audio toolkit (no DAWs, no native plugins — those come via Distrobox/Flatpak) ----------
# rtcqs (RT-config diagnostic) and cable (PipeWire tweaker) are upstream Python
# tools, not packaged in Audinux. The `audio-rt-check` ujust recipe installs
# rtcqs into the user's pipx environment on first use. cable is dropped —
# qpwgraph covers the runtime patchbay use case.
dnf5 install -y \
  qpwgraph \
  easyeffects \
  pipx

# Sanity-check: Aurora-DX already ships these; just assert they're present so a
# silent upstream removal doesn't ship a broken image.
rpm -q pipewire-jack-audio-connection-kit wireplumber

# ---------- Overlay our system files ----------
# Includes: bootc kargs.d, sysusers.d, /etc PipeWire/WirePlumber/limits/sysctl
# drop-ins, and /usr/share/ublue-os/just/60-audio.just.
cp -r /ctx/system_files/. /

# Process sysusers.d at build time so the `realtime` group is baked into the
# image's /etc/group instead of waiting for first-boot. The file at
# /usr/lib/sysusers.d/cadence-realtime-group.conf stays in place so future
# deployments and rebases re-assert the group declaratively.
systemd-sysusers

# ---------- Cleanup ----------
dnf5 clean all
rm -rf /var/cache/dnf5 /var/cache/dnf
