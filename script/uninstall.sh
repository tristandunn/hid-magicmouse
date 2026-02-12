#!/bin/bash

set -eou pipefail

# Remove the DKMS driver.
sudo dkms remove -m hid-magicmouse-custom -v 0.1.0 --all 2>/dev/null || true

# Remove the source directory.
sudo rm -rf /usr/src/hid-magicmouse-custom-0.1.0

# Remove configuration files.
sudo rm -f /etc/modules-load.d/hid-magicmouse.conf
sudo rm -f /etc/modprobe.d/hid-magicmouse.conf

# Rebuild the initramfs to remove stale configuration.
sudo mkinitcpio -P

# Reload the original module.
sudo modprobe -r hid_magicmouse
sudo modprobe hid_magicmouse
