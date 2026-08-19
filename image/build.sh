#!/usr/bin/env bash
# Build the FCOS snapshot for the artifact pinned in image/fcos.pin, or do
# nothing if that snapshot already exists.
#
# The pin is also read by image/fcos.pkr.hcl, so packer needs no -var for the
# artifact itself; what this script adds is the "already built?" early exit and
# a check that the pinned checksum still matches upstream.
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
    local field="${1}" value
    if ! value=$(jq -er ".${field}" <image/fcos.pin); then
        echo "image/fcos.pin: field '${field}' is missing or null" >&2
        exit 2
    fi
    printf '%s\n' "${value}"
}

STREAM="$(pin_field "stream")"
VERSION="$(pin_field "version")"
SHA256="$(pin_field "sha256")"

echo "fcos ${STREAM}/${VERSION}"

snapshot_id() {
    local want="${1}"
    curl -sSfL -H "Authorization: Bearer ${HCLOUD_TOKEN}" \
        "https://api.hetzner.cloud/v1/images?type=snapshot&label_selector=managed_by=raya,os=fcos,fcos_version=${want}" |
        jq -r '.images[0].id // empty'
}

existing=$(snapshot_id "${VERSION}")
if [ -n "${existing}" ]; then
    echo "snapshot ${existing} already holds this version, nothing to build"
    exit 0
fi

base="https://builds.coreos.fedoraproject.org/prod/streams/${STREAM}/builds/${VERSION}/x86_64"
upstream_sha256=$(curl -sSfL "${base}/meta.json" | jq -er '.images.hetzner.sha256 // empty')

if [ -z "${upstream_sha256}" ]; then
    echo "no hetzner artifact checksum for ${VERSION} in ${STREAM}" >&2
    exit 1
fi

if [ "${upstream_sha256}" != "${SHA256}" ]; then
    echo "image/fcos.pin sha256 does not match ${base}/meta.json" >&2
    echo "  pinned:   ${SHA256}" >&2
    echo "  upstream: ${upstream_sha256}" >&2
    exit 1
fi

packer init image/fcos.pkr.hcl
packer build \
    image/fcos.pkr.hcl
