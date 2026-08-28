#!/bin/bash

set -eou pipefail

# Fetches the upstream driver source matching a kernel version, applies the
# patch series, and writes the result to the source directory.
#
# Usage: source.sh [--allow-fallback] [--download <directory>] [<kernel-version>]
#
# With --download the upstream files are only fetched into a directory and the
# tag they came from is printed, which is what the patch tooling needs.

ROOT=$(cd "$(dirname "$0")/.." && pwd)

ALLOW_FALLBACK=0

if [[ "${1:-}" == "--allow-fallback" ]]; then
  ALLOW_FALLBACK=1
  shift
fi

DOWNLOAD_DIR=""

if [[ "${1:-}" == "--download" ]]; then
  DOWNLOAD_DIR="${2:-}"
  shift 2

  if [[ -z "$DOWNLOAD_DIR" ]]; then
    echo "Error: Missing directory for --download" >&2
    exit 1
  fi
fi

KVERSION="${1:-$(uname -r)}"
PATCH_DIR="${ROOT}/patches"
SOURCE_DIR="${SOURCE_DIR:-${ROOT}/source}"
CACHE_DIR="${CACHE_DIR:-${ROOT}/source/cache}"
UPSTREAM_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/drivers/hid"

WORK=""

cleanup() {
  if [[ -n "$WORK" ]]; then
    rm -rf "$WORK"
  fi
}

trap cleanup EXIT

# Aborts, or keeps the previously generated source when a fallback is allowed.
# A kernel upgrade must never leave the machine without a working driver.
fail() {
  echo "Error: $1" >&2

  if [[ "$ALLOW_FALLBACK" -eq 1 && -f "${SOURCE_DIR}/hid_magicmouse.c" ]]; then
    echo "Warning: reusing the existing source for ${KVERSION}." >&2
    exit 0
  fi

  exit 1
}

# Prints the candidate upstream tags for a kernel version, most specific first.
# A stable release such as 7.1.9-arch1-2 falls back to the 7.1 mainline tag.
kernel_tags() {
  local version="${1%%-*}"

  echo "v${version}"

  if [[ "$version" == *.*.* ]]; then
    echo "v${version%.*}"
  fi
}

# Downloads a file from the upstream tree at a tag, caching it between builds.
#
# The timeouts are important since this runs from PRE_BUILD during a kernel
# upgrade and the fallback only engages once curl returns.
fetch() {
  local tag="$1" name="$2" destination="$3"
  local cached="${CACHE_DIR}/${tag}/${name}"

  if [[ ! -f "$cached" ]]; then
    mkdir -p "$(dirname "$cached")"

    if ! curl -fsS --connect-timeout 10 --max-time 30 \
      -o "${cached}.download" "${UPSTREAM_URL}/${name}?h=${tag}"; then
      rm -f "${cached}.download"
      return 1
    fi

    mv "${cached}.download" "$cached"
  fi

  cp "$cached" "$destination"
}

# Downloads the upstream sources, printing the tag they were taken from.
resolve() {
  local tag

  for tag in $(kernel_tags "$KVERSION"); do
    if fetch "$tag" hid-magicmouse.c "${WORK}/upstream.c" &&
      fetch "$tag" hid-ids.h "${WORK}/hid-ids.h"; then
      echo "$tag"
      return 0
    fi
  done

  return 1
}

# Warns when an upstream version has not been recorded as verified. This is
# advisory only, since the merge below is what determines whether it applies.
verify() {
  local tag="$1" checksum

  checksum=$(sha256sum "${WORK}/upstream.c" | cut -d' ' -f1)

  if ! grep -qs -- "$checksum" "${PATCH_DIR}/verified"; then
    echo "Warning: upstream ${tag} has not been verified." >&2
  fi
}

# Applies the patch series to the base source. This is exact by construction,
# so a failure here means the series and the base have drifted apart.
apply_series() {
  local patch directory="${WORK}/series"

  mkdir -p "$directory"
  cp "${PATCH_DIR}/base/hid-magicmouse.c" "${directory}/hid-magicmouse.c"

  for patch in "${PATCH_DIR}"/[0-9]*.patch; do
    if ! patch -s -p1 -d "$directory" --batch --forward < "$patch"; then
      fail "Unable to apply $(basename "$patch") to the base source."
    fi
  done

  cp "${directory}/hid-magicmouse.c" "${WORK}/custom.c"
}

# Merges the customizations onto the upstream source for the target kernel.
merge() {
  local tag="$1" base="${PATCH_DIR}/base/hid-magicmouse.c"

  if cmp -s "${WORK}/upstream.c" "$base"; then
    return 0
  fi

  if ! git merge-file -L custom -L "$(cat "${PATCH_DIR}/base/version")" -L "$tag" \
    "${WORK}/custom.c" "$base" "${WORK}/upstream.c"; then
    echo "Conflicts between the patch series and upstream ${tag}:" >&2

    if ! grep -n '^<<<<<<< \|^>>>>>>> ' "${WORK}/custom.c" >&2; then
      echo "  (no conflict markers found)" >&2
    fi

    echo "Run './script/patches.sh rebase' to update the series." >&2

    fail "Unable to merge the patch series with upstream ${tag}."
  fi
}

mkdir -p "$CACHE_DIR"

WORK=$(mktemp -d)

if ! TAG=$(resolve); then
  fail "Unable to download the upstream source for ${KVERSION}."
fi

if [[ -n "$DOWNLOAD_DIR" ]]; then
  mkdir -p "$DOWNLOAD_DIR"
  cp "${WORK}/upstream.c" "${DOWNLOAD_DIR}/hid-magicmouse.c"
  cp "${WORK}/hid-ids.h" "${DOWNLOAD_DIR}/hid-ids.h"

  echo "$TAG"
  exit 0
fi

mkdir -p "$SOURCE_DIR"

verify "$TAG"
apply_series
merge "$TAG"

# The file is renamed to match the module name used by the generated Makefile.
cp "${WORK}/custom.c" "${SOURCE_DIR}/hid_magicmouse.c"
cp "${WORK}/hid-ids.h" "${SOURCE_DIR}/hid-ids.h"

echo "Prepared ${SOURCE_DIR}/hid_magicmouse.c from upstream ${TAG}."
