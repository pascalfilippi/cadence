# Audio recipes for cadence — low-latency PipeWire helpers
# Invoke with `ujust audio-<recipe>`

# Run the realtime config diagnostic (rtcqs). Installs it via pipx on first use
# since it's not packaged as an RPM in Audinux.
[group('Audio')]
audio-rt-check:
    #!/usr/bin/env bash
    set -euo pipefail
    # rtcqs only looks for the kernel config at /proc/config.gz or
    # /boot/config-$(uname -r). On atomic Fedora/Aurora neither exists: the Fedora
    # kernel is built with CONFIG_IKCONFIG off (no /proc/config.gz), and ostree keeps
    # the config at /usr/lib/modules/<rel>/config instead of populating /boot. When
    # rtcqs can't find it, it not only skips the kernel checks but crashes
    # (KeyError on self.kernel["config"] in high_res_timers_check). Restore the
    # conventional /boot path as a symlink so the kernel checks run. Done at runtime
    # so it tracks the running kernel even after an `audio-install-cachyos*` swap.
    rel="$(uname -r)"
    cfg="/usr/lib/modules/${rel}/config"
    if [[ -r "$cfg" && ! -e "/boot/config-${rel}" ]]; then
        echo "Linking kernel config into /boot so rtcqs can read it (needs sudo, one-time)…"
        sudo ln -sf "$cfg" "/boot/config-${rel}"
    fi
    if ! command -v rtcqs >/dev/null 2>&1; then
        echo "rtcqs not installed — fetching via pipx (one-time)..."
        pipx install rtcqs
    fi
    export PATH="$HOME/.local/bin:$PATH"
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

# Toggle SMT / hyper-threading at runtime. Disabling halves logical cores but can
# remove the DSP-load spikes rtcqs warns about under heavy realtime audio. This is
# NOT persistent — it resets to the firmware default on reboot. Leave it on for
# gaming; flip it off for a low-latency session if you hit xruns.
# Usage: `ujust audio-smt on|off|status`  (no argument shows current state)
[group('Audio')]
audio-smt action="status":
    #!/usr/bin/env bash
    set -euo pipefail
    case "{{ action }}" in
        on|off)
            echo "{{ action }}" | sudo tee /sys/devices/system/cpu/smt/control >/dev/null
            echo "SMT set to '{{ action }}'." ;;
        status) ;;
        *)
            echo "Usage: ujust audio-smt on|off|status" >&2
            exit 1 ;;
    esac
    echo "control: $(cat /sys/devices/system/cpu/smt/control)"
    echo "active:  $(cat /sys/devices/system/cpu/smt/active)  (1 = SMT active, 0 = disabled)"

# Pin the CPU to a deterministic, low-latency state for playing/recording.
# Aurora manages CPU frequency scaling through tuned (the KDE energy widget drives
# it via tuned-ppd) — NOT power-profiles-daemon or raw cpupower, so rtcqs's
# `cpupower frequency-set -g performance` tip won't stick: tuned re-asserts its
# profile. The correct lever is the tuned profile. This selects `latency-performance`
# (governor=performance, EPP=performance, min_perf_pct=100, capped CPU C-states and
# vm.swappiness=10). It also overwrites any stale active profile, so it doubles as the
# fix if the KDE "Performance" setting isn't taking effect. Reverse with audio-cpu-balanced.
[group('Audio')]
audio-cpu-performance:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo tuned-adm profile latency-performance
    echo "Active profile: $(tuned-adm active | cut -d: -f2- | xargs)"
    echo "Governor now:   $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"

# Hand CPU frequency scaling back to the balanced default (and to the KDE energy
# widget / tuned-ppd). Use this after a session to restore normal power management.
[group('Audio')]
audio-cpu-balanced:
    #!/usr/bin/env bash
    set -euo pipefail
    sudo tuned-adm profile balanced
    echo "Active profile: $(tuned-adm active | cut -d: -f2- | xargs)"

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
