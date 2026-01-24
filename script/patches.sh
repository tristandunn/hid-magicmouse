#!/bin/bash

set -eou pipefail

case "${1:-}" in
	download)
		# Download the source file.
		TMP_FILE=$(mktemp)
		curl -sS -o "$TMP_FILE" \
			https://raw.githubusercontent.com/torvalds/linux/master/drivers/hid/hid-magicmouse.c

		# Hash it and create the patch directory.
		MD5=$(md5sum "$TMP_FILE" | cut -d' ' -f1)
		PATCH_DIR="patches/${MD5}"
		mkdir -p "$PATCH_DIR"

		# Move the file to the patch directory.
		mv "$TMP_FILE" "${PATCH_DIR}/original.c"

		# Create modified.c if it doesn't exist.
		if [[ ! -f "${PATCH_DIR}/modified.c" ]]; then
			cp "${PATCH_DIR}/original.c" "${PATCH_DIR}/modified.c"
		fi

		echo "Downloaded to ${PATCH_DIR}/original.c"
		;;

	build)
		PATCH_DIR="${2:-}"
		if [[ -z "$PATCH_DIR" ]]; then
			echo "Error: Missing patch directory argument" >&2
			echo "Usage: $0 build patches/<md5>" >&2
			exit 1
		fi

		if [[ ! -f "${PATCH_DIR}/original.c" ]]; then
			echo "Error: ${PATCH_DIR}/original.c not found" >&2
			exit 1
		fi

		if [[ ! -f "${PATCH_DIR}/modified.c" ]]; then
			echo "Error: ${PATCH_DIR}/modified.c not found" >&2
			exit 1
		fi

		# Generate the patch.
		diff -u "${PATCH_DIR}/original.c" "${PATCH_DIR}/modified.c" \
			> "${PATCH_DIR}/hid-magicmouse.patch" || true

		echo "Generated ${PATCH_DIR}/hid-magicmouse.patch"
		;;

	*)
		echo "Usage: $0 <command>" >&2
		echo "" >&2
		echo "Commands:" >&2
		echo "  download              Download source and create patches/<md5>/original.c" >&2
		echo "  build patches/<md5>   Build patch from original.c and modified.c" >&2
		exit 1
		;;
esac
