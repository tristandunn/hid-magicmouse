#!/bin/bash

set -eou pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(cat "${ROOT}/VERSION")

# Fetch the upstream source for this kernel and apply the patch series.
"${ROOT}/script/source.sh" "$@"

# Create the Makefile.
cat << 'EOF' | tee "${ROOT}/source/Makefile" > /dev/null
obj-m := hid_magicmouse.o

KVERSION := $(shell uname -r)

all:
	make -C /lib/modules/$(KVERSION)/build M=$(CURDIR) modules

clean:
	make -C /lib/modules/$(KVERSION)/build M=$(CURDIR) clean
EOF

# Create the DKMS configuration.
#
# PRE_BUILD re-runs the source pipeline for the kernel being built, so a kernel
# upgrade compiles the driver for that kernel instead of the one installed
# against. It falls back to the source already present when the upstream file
# cannot be fetched or merged, so an upgrade never leaves the mouse without a
# driver. SOURCE_DIR is the build directory itself, since DKMS flattens the
# source files, and the cache lives outside it so it survives a rebuild.
cat << EOF | tee "${ROOT}/source/dkms.conf" > /dev/null
PACKAGE_NAME="hid-magicmouse-custom"
PACKAGE_VERSION="${VERSION}"
BUILT_MODULE_NAME="hid_magicmouse"
DEST_MODULE_LOCATION="/kernel/drivers/hid"
AUTOINSTALL="yes"
PRE_BUILD="env SOURCE_DIR=. CACHE_DIR=/var/cache/hid-magicmouse-custom script/source.sh --allow-fallback \${kernelver}"
MAKE[0]="make -C /lib/modules/\${kernelver}/build M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build modules"
EOF
