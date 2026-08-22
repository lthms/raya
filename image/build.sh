#!/usr/bin/env bash
# Build the snapshot for the pair pinned in image/fcos.pin and image/k3s.pin, or
# do nothing if that snapshot already exists.
#
# Both pins are also read by image/fcos.pkr.hcl, so packer needs no -var for the
# artifacts themselves; what this script adds is the "already built?" early exit
# and a check that the pinned checksums still match upstream.
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
SHA256="$(pin_field "fcos" "sha256")"

K3S_VERSION="$(pin_field "k3s" "version")"
K3S_SHA256="$(pin_field "k3s" "sha256")"

# Hetzner label values reject `+`; image/fcos.pkr.hcl and locals.tf apply the
# same rewrite, and all three have to agree.
K3S_LABEL="${K3S_VERSION//+/-}"

echo "fcos ${STREAM}/${VERSION} with k3s ${K3S_VERSION}"

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

# k3s publishes one checksum file per release listing every artifact; we only
# care about the plain `k3s` binary.
k3s_release="https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION//+/%2B}"
k3s_upstream_sha256=$(curl -sSfL "${k3s_release}/sha256sum-amd64.txt" | awk '$2 == "k3s" { print $1 }')

if [ -z "${k3s_upstream_sha256}" ]; then
    echo "no k3s binary checksum for ${K3S_VERSION}" >&2
    exit 1
fi

if [ "${k3s_upstream_sha256}" != "${K3S_SHA256}" ]; then
    echo "image/k3s.pin sha256 does not match ${k3s_release}/sha256sum-amd64.txt" >&2
    echo "  pinned:   ${K3S_SHA256}" >&2
    echo "  upstream: ${k3s_upstream_sha256}" >&2
    exit 1
fi

packer init image/fcos.pkr.hcl
packer build \
    image/fcos.pkr.hcl
