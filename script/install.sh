#!/bin/bash

set -eou pipefail

VERSION=$(cat "$(dirname "$0")/../VERSION")

# Install dependencies.
sudo pacman -S --needed dkms linux-headers

# Create the source directory.
sudo mkdir -p /usr/src/hid-magicmouse-custom-${VERSION}

# Copy all source files.
sudo cp ./source/* /usr/src/hid-magicmouse-custom-${VERSION}/

# Clear and register the driver.
sudo dkms remove -m hid-magicmouse-custom -v ${VERSION} --all 2>/dev/null || true
sudo dkms build -m hid-magicmouse-custom -v ${VERSION}
sudo dkms install -m hid-magicmouse-custom -v ${VERSION}

# Create a default configuration if one doesn't exist.
if [ ! -e /etc/modprobe.d/hid-magicmouse.conf ]; then
  sudo cp ./config/hid-magicmouse.conf /etc/modprobe.d/hid-magicmouse.conf
fi

# Ensure the module loads at boot.
echo "hid_magicmouse" | sudo tee /etc/modules-load.d/hid-magicmouse.conf > /dev/null

# Rebuild the initramfs to include new configuration.
sudo mkinitcpio -P

# Reload the module.
sudo modprobe -r hid_magicmouse
sudo modprobe hid_magicmouse
