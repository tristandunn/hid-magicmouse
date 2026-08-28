#!/bin/bash

set -eou pipefail

# Manages the patch series applied to the upstream driver.
#
# The series lives in patches/ as a numbered set of git patches, rebased onto
# the upstream source recorded in patches/base. Updating the series for a new
# kernel is an ordinary git rebase rather than a manual re-edit.

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PATCH_DIR="${ROOT}/patches"
WORK_DIR="${ROOT}/.work"
REPO_DIR="${WORK_DIR}/repo"

if [[ ! -f "${PATCH_DIR}/base/version" ]]; then
  echo "Error: Missing ${PATCH_DIR}/base/version." >&2
  exit 1
fi

BASE_VERSION=$(cat "${PATCH_DIR}/base/version")

# Prints the subject line of a patch file.
subject() {
  sed -n 's/^Subject: //p' "$1" | head -1
}

# Lowercases the generated patch filenames, which git derives from the
# capitalized commit subjects.
normalize() {
  local patch lowercase

  for patch in "${PATCH_DIR}"/[0-9]*.patch; do
    lowercase="$(dirname "$patch")/$(basename "$patch" | tr '[:upper:]' '[:lower:]')"

    if [[ "$patch" != "$lowercase" ]]; then
      mv "$patch" "$lowercase"
    fi
  done
}

# Prepares the scratch repository: the base source, then one commit per patch.
prepare() {
  local name="Patch Series"
  local email="patches@localhost"

  git init -q -b custom "$REPO_DIR"

  if git config user.name > /dev/null; then
    name=$(git config user.name)
  fi

  if git config user.email > /dev/null; then
    email=$(git config user.email)
  fi

  git -C "$REPO_DIR" config user.name "$name"
  git -C "$REPO_DIR" config user.email "$email"
  git -C "$REPO_DIR" config commit.gpgsign false

  cp "${PATCH_DIR}/base/hid-magicmouse.c" "${REPO_DIR}/hid-magicmouse.c"

  git -C "$REPO_DIR" add hid-magicmouse.c
  git -C "$REPO_DIR" commit -q -m "Upstream ${BASE_VERSION}."
  git -C "$REPO_DIR" tag base

  git -C "$REPO_DIR" am -q "${PATCH_DIR}"/[0-9]*.patch
}

case "${1:-}" in
  status)
    echo "Base:   ${BASE_VERSION}"
    echo "Series:"

    for patch in "${PATCH_DIR}"/[0-9]*.patch; do
      printf '  %-6s %s\n' "$(basename "$patch" | cut -d- -f1)" "$(subject "$patch")"
    done

    echo "Verified:"

    if [[ -f "${PATCH_DIR}/verified" ]]; then
      sed 's/^/  /' "${PATCH_DIR}/verified"
    else
      echo "  none"
    fi

    TARGET="${2:-$(uname -r)}"
    STAGING=$(mktemp -d)

    echo "Target: ${TARGET}"

    if SOURCE_DIR="$STAGING" "${ROOT}/script/source.sh" "$TARGET" > /dev/null 2>&1; then
      echo "        applies cleanly"
    else
      echo "        needs a rebase, run: make rebase"
    fi

    rm -rf "$STAGING"
    ;;

  rebase)
    TARGET="${2:-$(uname -r)}"

    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"

    TAG=$("${ROOT}/script/source.sh" --download "${WORK_DIR}/upstream" "$TARGET")
    echo "$TAG" > "${WORK_DIR}/target"

    prepare

    # Record the new upstream as a sibling of the base, then replay the
    # series onto it so each conflict is attributed to one patch.
    git -C "$REPO_DIR" checkout -q --detach base
    cp "${WORK_DIR}/upstream/hid-magicmouse.c" "${REPO_DIR}/hid-magicmouse.c"

    # Rebasing onto the version already recorded leaves nothing to commit,
    # which is the normal case when editing the series in place.
    if ! git -C "$REPO_DIR" diff --quiet; then
      git -C "$REPO_DIR" commit -q -am "Upstream ${TAG}."
    fi

    git -C "$REPO_DIR" branch upstream
    git -C "$REPO_DIR" checkout -q custom

    echo "Rebasing the series from ${BASE_VERSION} onto ${TAG}."

    if git -C "$REPO_DIR" rebase -q --onto upstream base custom; then
      echo "Rebased cleanly. Run 'make export' to update the series."
    else
      echo "" >&2
      echo "Resolve the conflicts in ${REPO_DIR}, then:" >&2
      echo "  git -C ${REPO_DIR} add hid-magicmouse.c" >&2
      echo "  git -C ${REPO_DIR} rebase --continue" >&2
      echo "" >&2
      echo "Once the rebase finishes, run 'make export'." >&2
      exit 1
    fi
    ;;

  export)
    if [[ ! -d "$REPO_DIR" || ! -f "${WORK_DIR}/target" ]]; then
      echo "Error: No rebase in progress. Run 'make rebase' first." >&2
      exit 1
    fi

    if [[ -d "${REPO_DIR}/.git/rebase-merge" || -d "${REPO_DIR}/.git/rebase-apply" ]]; then
      echo "Error: The rebase is unfinished. Complete it first." >&2
      exit 1
    fi

    TAG=$(cat "${WORK_DIR}/target")
    STAGING="${WORK_DIR}/series"

    rm -rf "$STAGING"
    mkdir -p "$STAGING"

    # Generate into a staging directory so a failure here cannot destroy
    # the series that is already committed.
    if ! git -C "$REPO_DIR" format-patch -q -k --no-signature --zero-commit \
      -o "$STAGING" upstream..custom; then
      echo "Error: Unable to generate the series." >&2
      exit 1
    fi

    if ! compgen -G "${STAGING}/[0-9]*.patch" > /dev/null; then
      echo "Error: The rebase produced no patches." >&2
      exit 1
    fi

    # Replace the old series only now, so a dropped patch does not linger.
    rm -f "${PATCH_DIR}"/[0-9]*.patch
    mv "${STAGING}"/[0-9]*.patch "$PATCH_DIR"

    normalize

    cp "${WORK_DIR}/upstream/hid-magicmouse.c" "${PATCH_DIR}/base/hid-magicmouse.c"
    echo "$TAG" > "${PATCH_DIR}/base/version"

    # The previous entries described a different base, so start over.
    printf '%s %s\n' "$TAG" \
      "$(sha256sum "${PATCH_DIR}/base/hid-magicmouse.c" | cut -d' ' -f1)" \
      > "${PATCH_DIR}/verified"

    rm -rf "$WORK_DIR"

    echo "Exported the series rebased onto ${TAG}."
    ;;

  verify)
    TARGET="${2:-$(uname -r)}"
    STAGING=$(mktemp -d)

    trap 'rm -rf "$STAGING"' EXIT

    TAG=$("${ROOT}/script/source.sh" --download "${STAGING}/upstream" "$TARGET")

    if ! SOURCE_DIR="$STAGING" "${ROOT}/script/source.sh" "$TARGET" > /dev/null; then
      echo "Error: The series does not apply to ${TAG}." >&2
      exit 1
    fi

    CHECKSUM=$(sha256sum "${STAGING}/upstream/hid-magicmouse.c" | cut -d' ' -f1)

    if grep -qs -- "$CHECKSUM" "${PATCH_DIR}/verified"; then
      echo "${TAG} is already verified."
    else
      printf '%s %s\n' "$TAG" "$CHECKSUM" >> "${PATCH_DIR}/verified"
      echo "Recorded ${TAG} as verified."
    fi
    ;;

  *)
    echo "Usage: $0 <command>" >&2
    echo "" >&2
    echo "Commands:" >&2
    echo "  status [<kernel-version>]   Show the series and whether it applies" >&2
    echo "  rebase [<kernel-version>]   Rebase the series onto a newer upstream" >&2
    echo "  export                      Write the rebased series back to patches/" >&2
    echo "  verify [<kernel-version>]   Record a version the series applies to" >&2
    exit 1
    ;;
esac
