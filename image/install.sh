#!/usr/bin/env bash
# Runs as root inside the Hetzner rescue system, over SSH from packer.
#
# Writes the upstream FCOS hetzner disk image over the builder's disk, then adds
# the pinned k3s binary to it. That artifact is built with
# ignition.platform.id=hetzner, so a server made from the resulting snapshot
# reads its Ignition config from hcloud user_data; the only thing baked in here
# is the k3s binary.
#
# Inputs:
#   FCOS_IMAGE_URL, FCOS_IMAGE_SHA256  (required)  set by fcos.pkr.hcl from image/fcos.pin
#   K3S_BINARY_URL, K3S_BINARY_SHA256  (required)  set by fcos.pkr.hcl from image/k3s.pin
#   DISK                               (optional)  block device to overwrite [/dev/sda]
set -euo pipefail


for var in FCOS_IMAGE_URL FCOS_IMAGE_SHA256 K3S_BINARY_URL K3S_BINARY_SHA256; do
    if [ -z "${!var:-}" ]; then
        echo "${var} must be set" >&2
        exit 1
    fi
done

DISK="${DISK:-/dev/sda}"

if [ ! -b "${DISK}" ]; then
    echo "${DISK} is not a block device" >&2
    exit 1
fi

curl -sSfL -o /tmp/k3s "${K3S_BINARY_URL}"
echo "${K3S_BINARY_SHA256}  /tmp/k3s" | sha256sum -c -

curl -sSfL -o /tmp/fcos.raw.xz "${FCOS_IMAGE_URL}"
echo "${FCOS_IMAGE_SHA256}  /tmp/fcos.raw.xz" | sha256sum -c -

xz -dc /tmp/fcos.raw.xz | dd of="${DISK}" bs=4M status=progress
sync

partprobe "${DISK}"
udevadm settle

# /usr/local is a symlink to /var/usrlocal on FCOS, and /var lives inside the
# root filesystem at ostree/deploy/fedora-coreos/var. That directory survives
# provisioning: first boot creates what is missing under /var, it does not wipe
# what is already there.
ROOT_MNT="$(mktemp -d)"
mount /dev/disk/by-label/root "${ROOT_MNT}"
trap 'umount "${ROOT_MNT}" || true; rmdir "${ROOT_MNT}" || true' EXIT

VAR_DIR="${ROOT_MNT}/ostree/deploy/fedora-coreos/var"

mkdir -p "${VAR_DIR}/usrlocal/bin"
install -o 0 -g 0 -m 0755 /tmp/k3s "${VAR_DIR}/usrlocal/bin/k3s"

sync
