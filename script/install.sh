#!/bin/bash

set -eou pipefail

# Install dependencies.
sudo pacman -S --needed dkms linux-headers

# Create the source directory.
sudo mkdir -p /usr/src/hid-magicmouse-custom-0.1.0

# Copy all source files.
sudo cp ./source/* /usr/src/hid-magicmouse-custom-0.1.0/

# Clear and register the driver.
sudo dkms remove -m hid-magicmouse-custom -v 0.1.0 --all 2>/dev/null || true
sudo dkms build -m hid-magicmouse-custom -v 0.1.0
sudo dkms install -m hid-magicmouse-custom -v 0.1.0

# Create a default configuration if one doesn't exist.
if [ ! -e /etc/modprobe.d/hid-magicmouse.conf ]; then
  sudo cp ./config/hid-magicmouse.conf /etc/modprobe.d/hid-magicmouse.conf
fi

# Reload the module.
sudo modprobe -r hid_magicmouse
sudo modprobe hid_magicmouse
