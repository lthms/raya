#!/usr/bin/env bash
# Build the snapshot for the pair pinned in image/fcos.pin and image/k3s.pin, or
# do nothing if that snapshot already exists.
#
# Both pins are also read by image/fcos.pkr.hcl, so packer needs no -var for the
# artifacts themselves; what this script adds is the "already built?" early exit
# and a call to image/check-pins.sh.
#
# Inputs:
#   HCLOUD_TOKEN  (required)  Hetzner Cloud API token
set -euo pipefail

cd "$(dirname "${0}")/.."

if [ -z "${HCLOUD_TOKEN:-}" ]; then
    echo "HCLOUD_TOKEN must be set" >&2
    exit 1
fi

pin_field() {
    local pin="${1}" field="${2}" value
    if ! value=$(jq -er ".${field}" <"image/${pin}.pin"); then
        echo "image/${pin}.pin: field '${field}' is missing or null" >&2
        exit 2
    fi
    printf '%s\n' "${value}"
}

STREAM="$(pin_field "fcos" "stream")"
VERSION="$(pin_field "fcos" "version")"

K3S_VERSION="$(pin_field "k3s" "version")"

# Hetzner label values reject `+`; image/fcos.pkr.hcl and locals.tf apply the
# same rewrite, and all three have to agree.
K3S_LABEL="${K3S_VERSION//+/-}"

echo "fcos ${STREAM}/${VERSION} with k3s ${K3S_VERSION}"

image/check-pins.sh

snapshot_id() {
    local want_fcos="${1}" want_k3s="${2}"
    curl -sSfL -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
        "https://api.hetzner.cloud/v1/images?type=snapshot&label_selector=managed_by=raya,os=fcos,fcos_version=${want_fcos},k3s_version=${want_k3s}" |
        jq -r '.images[0].id // empty'
}

existing=$(snapshot_id "${VERSION}" "${K3S_LABEL}")
if [ -n "${existing}" ]; then
    echo "snapshot ${existing} already holds this pair, nothing to build"
    exit 0
fi

packer init image/fcos.pkr.hcl
packer build \
    image/fcos.pkr.hcl
