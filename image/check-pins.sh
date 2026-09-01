#!/usr/bin/env bash
# Check that the sha256 pinned in image/fcos.pin and image/k3s.pin still matches
# what upstream publishes for the pinned version.
#
# Split out of image/build.sh so a pull request can run it: build.sh needs
# HCLOUD_TOKEN and only runs on main, so a version bump with a stale checksum
# used to reach main before anything compared the two.
#
# No inputs.
set -euo pipefail

cd "$(dirname "${0}")/.."

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

echo "fcos ${STREAM}/${VERSION} and k3s ${K3S_VERSION} checksums match upstream"

