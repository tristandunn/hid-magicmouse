#!/bin/bash

set -eou pipefail

# Fetch the source files.
mkdir -p ./source
curl -sS -o ./source/hid_magicmouse.c \
	https://raw.githubusercontent.com/torvalds/linux/master/drivers/hid/hid-magicmouse.c
curl -sS -o ./source/hid-ids.h \
	https://raw.githubusercontent.com/torvalds/linux/master/drivers/hid/hid-ids.h

# Determine the patch file based on MD5 of the source.
MD5=$(md5sum ./source/hid_magicmouse.c | cut -d' ' -f1)
PATCH_FILE="patches/${MD5}/hid-magicmouse.patch"

if [[ ! -f "$PATCH_FILE" ]]; then
	echo "Error: No patch file found. (Expected: ${PATCH_FILE})" >&2
	exit 1
fi

# Apply the patch.
patch -s ./source/hid_magicmouse.c "$PATCH_FILE"

# Create the Makefile.
cat << 'EOF' | tee ./source/Makefile > /dev/null
obj-m := hid_magicmouse.o

KVERSION := $(shell uname -r)

all:
	make -C /lib/modules/$(KVERSION)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(KVERSION)/build M=$(PWD) clean
EOF

# Create the DKMS configuration.
cat << 'EOF' | tee ./source/dkms.conf > /dev/null
PACKAGE_NAME="hid-magicmouse-custom"
PACKAGE_VERSION="0.1.0"
BUILT_MODULE_NAME="hid_magicmouse"
DEST_MODULE_LOCATION="/kernel/drivers/hid"
AUTOINSTALL="yes"
EOF
