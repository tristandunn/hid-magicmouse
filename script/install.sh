#!/bin/bash

set -eou pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
VERSION=$(cat "${ROOT}/VERSION")

# Remove every registered version, not just this one. Otherwise two versions of
# the package would both autoinstall and fight over the same module.
for source in /usr/src/hid-magicmouse-custom-*; do
  if [ ! -d "${source}" ]; then
    continue
  fi

  previous="${source##*/hid-magicmouse-custom-}"

  if ! sudo dkms remove -m hid-magicmouse-custom -v "${previous}" --all 2> /dev/null; then
    echo "No DKMS module registered for version ${previous}."
  fi

  sudo rm -rf "${source}"
done

# Create the source directory.
sudo mkdir -p /usr/src/hid-magicmouse-custom-${VERSION}

# Copy the generated source files.
sudo cp "${ROOT}"/source/{hid_magicmouse.c,hid-ids.h,Makefile,dkms.conf} \
  /usr/src/hid-magicmouse-custom-${VERSION}/

# Copy the patch series and tooling so DKMS can regenerate the source for
# whichever kernel it is building against.
sudo cp -r "${ROOT}/patches" /usr/src/hid-magicmouse-custom-${VERSION}/
sudo mkdir -p /usr/src/hid-magicmouse-custom-${VERSION}/script
sudo cp "${ROOT}/script/source.sh" /usr/src/hid-magicmouse-custom-${VERSION}/script/
sudo mkdir -p /var/cache/hid-magicmouse-custom

# Register the driver.
sudo dkms build -m hid-magicmouse-custom -v ${VERSION}
sudo dkms install -m hid-magicmouse-custom -v ${VERSION}

# Create a default configuration if one doesn't exist.
if [ ! -e /etc/modprobe.d/hid-magicmouse.conf ]; then
  sudo cp "${ROOT}/config/hid-magicmouse.conf" /etc/modprobe.d/hid-magicmouse.conf
fi

# Ensure the module loads at boot.
echo "hid_magicmouse" | sudo tee /etc/modules-load.d/hid-magicmouse.conf > /dev/null

# Rebuild the initramfs to include new configuration.
sudo mkinitcpio -P

# Reload the module.
sudo modprobe -r hid_magicmouse
sudo modprobe hid_magicmouse
