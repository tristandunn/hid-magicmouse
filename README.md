# Customized Apple Magic Mouse 2 Driver

A customized driver to improve the Apple Magic Mouse experience, especially for
people migrating from macOS.

- Prevent scrolling when the mouse is moving.
- Reset scroll tracking when the mouse moves.
- Decrease the maximum scroll acceleration.

## Installation

> [!NOTE]
> Currently only tested on Arch Linux.

To build and install the driver, including dependencies, you can run:

```sh
make install
```

If you'd like to build the source to preview it before installing, run:

```sh
make build
```

To uninstall the driver and restore the original:

```sh
make uninstall
```

## Configuration

The driver can be configured via module parameters. To change settings at runtime:

```sh
# Enable scrolling while the mouse is moving, which is disabled by default.
echo 1 | sudo tee /sys/module/hid_magicmouse/parameters/scroll_while_moving
```

To make settings persistent, create a modprobe configuration file:

```sh
# /etc/modprobe.d/hid-magicmouse.conf
options hid_magicmouse scroll_while_moving=1
```

Available parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `scroll_while_moving` | `0` | Allow scrolling while the mouse is moving. |
| `scroll_acceleration` | `0` | Enable scroll acceleration. |
| `scroll_speed` | `32` | Scroll speed from 0-63, where higher is faster. |
| `emulate_scroll_wheel` | `1` | Enable touch-to-scroll emulation. |
| `emulate_3button` | `1` | Enable middle/right click emulation. |

## Patches

This project applies patches to the upstream Linux `hid-magicmouse.c` driver. To
ensure patches are only applied to the exact source version they were created
for, the build process will:

1. Download the latest `hid-magicmouse.c` from the Linux kernel repository.
2. Compute the MD5 hash of the downloaded file.
3. Look for a matching patch in `patches/<md5>/hid-magicmouse.patch`.
4. Apply the patch only if a matching version exists.

This prevents patches from being applied to incompatible source versions.

### Creating a New Patch

When the upstream driver changes, you'll need to create a new patch:

1. Download the new source and create the patch directory:

   ```sh
   ./script/patches.sh download
   ```

   This downloads the current `hid-magicmouse.c`, computes its MD5, and creates
   `patches/<md5>/original.c` and `patches/<md5>/modified.c`.
2. Edit `patches/<md5>/modified.c` with your changes.
3. Generate the patch file:

   ```sh
   ./script/patches.sh build patches/<md5>
   ```

   This creates `patches/<md5>/hid-magicmouse.patch` from the diff between `original.c` and `modified.c`.

## License

See [LICENSE](LICENSE) for more details.
