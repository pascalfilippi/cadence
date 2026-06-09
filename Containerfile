# Base image is parameterized via the BASE_IMAGE build-arg.
# CI builds two variants from a matrix:
#   - cadence         → aurora-dx                 (no GPU drivers)
#   - cadence-nvidia  → aurora-dx-nvidia-open     (Turing+ NVIDIA cards)
# Local default = non-NVIDIA. Use `just build-nvidia` for the NVIDIA variant.
# Global ARG must precede every FROM so it can be referenced in FROM lines.
ARG BASE_IMAGE=ghcr.io/ublue-os/aurora-dx:stable

# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

FROM ${BASE_IMAGE}

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

RUN bootc container lint
