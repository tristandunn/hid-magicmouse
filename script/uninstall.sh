#!/bin/bash

set -eou pipefail

# Remove every registered version, so bumping the version cannot leave an older
# one orphaned and still autoinstalling.
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

# Remove the upstream source cache.
sudo rm -rf /var/cache/hid-magicmouse-custom

# Remove configuration files.
sudo rm -f /etc/modules-load.d/hid-magicmouse.conf
sudo rm -f /etc/modprobe.d/hid-magicmouse.conf

# Rebuild the initramfs to remove stale configuration.
sudo mkinitcpio -P

# Reload the original module.
sudo modprobe -r hid_magicmouse
sudo modprobe hid_magicmouse
