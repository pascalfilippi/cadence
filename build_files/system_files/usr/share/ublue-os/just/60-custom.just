# Audio recipes for cadence — low-latency PipeWire helpers
# Invoke with `ujust audio-<recipe>`

# Run the realtime config diagnostic (rtcqs). Installs it via pipx on first use
# since it's not packaged as an RPM in Audinux.
[group('Audio')]
audio-rt-check:
    #!/usr/bin/env bash
    if ! command -v rtcqs >/dev/null 2>&1; then
        echo "rtcqs not installed — fetching via pipx (one-time)..."
        pipx install rtcqs
        export PATH="$HOME/.local/bin:$PATH"
    fi
    rtcqs

# Force the PipeWire quantum (buffer size) at runtime. Lower = lower latency, higher CPU.
# Example: `ujust audio-set-quantum 128`
[group('Audio')]
audio-set-quantum quantum="128":
    #!/usr/bin/env bash
    pw-metadata -n settings 0 clock.force-quantum {{ quantum }}

# Reset to PipeWire defaults from /etc/pipewire/pipewire.conf.d
[group('Audio')]
audio-reset-quantum:
    #!/usr/bin/env bash
    pw-metadata -n settings 0 clock.force-quantum 0
    pw-metadata -n settings 0 clock.force-rate 0

# Add yourself to the realtime group so the RT priority/memlock limits in
# /etc/security/limits.d/95-realtime.conf apply. Requires a full re-login.
[group('Audio')]
audio-join-realtime-group:
    #!/usr/bin/env bash
    sudo gpasswd -a "$USER" realtime
    @echo "Done. Log out and back in for RT limits to take effect."
    @echo "Verify with: ulimit -r  (expect 95)"

# Opt-in: swap the stock kernel for kernel-cachyos (BORE+EEVDF, PREEMPT_DYNAMIC).
# Better desktop responsiveness under load. Not real-time — for that use the
# `audio-install-cachyos-rt` recipe instead. Requires x86-64-v3 CPU.
# Triggers an NVIDIA akmod rebuild on next boot (a few minutes).
[group('Audio')]
audio-install-cachyos:
    #!/usr/bin/env bash
    @echo "This swaps the stock Fedora kernel for kernel-cachyos (BORE+EEVDF, PREEMPT_DYNAMIC)."
    @echo "NVIDIA akmod will rebuild against the new kernel on next boot."
    @echo "Requires an x86-64-v3 CPU (most modern gaming/audio PCs qualify)."
    @echo "See: https://discussion.fedoraproject.org/t/bieszczaders-kernel-cachyos/46112"
    @echo ""
    @echo "Press Ctrl-C to abort, or Enter to continue."
    @read -r _
    sudo dnf5 -y copr enable bieszczaders/kernel-cachyos
    sudo rpm-ostree override remove \
        kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra \
        --install kernel-cachyos
    @echo "Reboot to apply."

# Opt-in: swap the stock kernel for kernel-cachyos-rt (PREEMPT_RT).
# Provides hard real-time scheduling. Will trigger akmod-NVIDIA to rebuild
# against the new kernel on next boot, which can take a few minutes.
[group('Audio')]
audio-install-cachyos-rt:
    #!/usr/bin/env bash
    @echo "This swaps the stock Fedora kernel for kernel-cachyos-rt (PREEMPT_RT)."
    @echo "NVIDIA akmod will rebuild against the new kernel on next boot."
    @echo "See: https://discussion.fedoraproject.org/t/bieszczaders-kernel-cachyos/46112"
    @echo ""
    @echo "Press Ctrl-C to abort, or Enter to continue."
    @read -r _
    sudo dnf5 -y copr enable bieszczaders/kernel-cachyos
    sudo rpm-ostree override remove \
        kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra \
        --install kernel-cachyos-rt
    @echo "Reboot to apply."
