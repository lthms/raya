#!/usr/bin/env bash
# Runs as root inside the Hetzner rescue system, over SSH from packer.
#
# Writes the upstream FCOS hetzner disk image over the builder's disk. That
# artifact is built with ignition.platform.id=hetzner, so a server made from the
# resulting snapshot reads its Ignition config from hcloud user_data — nothing
# repo-specific is baked in here.
#
# Inputs:
#   FCOS_IMAGE_URL, FCOS_IMAGE_SHA256  (required)  set by fcos.pkr.hcl from the pin
#   DISK                               (optional)  block device to overwrite [/dev/sda]
set -euo pipefail


if [ -z "${FCOS_IMAGE_URL:-}" ]; then
    echo "FCOS_IMAGE_URL must be set" >&2
    exit 1
fi

if [ -z "${FCOS_IMAGE_SHA256:-}" ]; then
    echo "FCOS_IMAGE_SHA256 must be set" >&2
    exit 1
fi

DISK="${DISK:-/dev/sda}"

if [ ! -b "${DISK}" ]; then
    echo "${DISK} is not a block device" >&2
    exit 1
fi

curl -sSfL -o /tmp/fcos.raw.xz "${FCOS_IMAGE_URL}"
echo "${FCOS_IMAGE_SHA256}  /tmp/fcos.raw.xz" | sha256sum -c -

xz -dc /tmp/fcos.raw.xz | dd of="${DISK}" bs=4M status=progress
sync
