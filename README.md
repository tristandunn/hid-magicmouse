# Customized Apple Magic Mouse 2 Driver

A customized driver to improve the Apple Magic Mouse experience, especially for
people migrating from macOS.

- Prevent scrolling when the mouse is moving or a button is held.
- Reset scroll tracking when the mouse moves.
- Decrease the maximum scroll acceleration.
- Report battery status.

## Installation

> [!NOTE]
> Currently only tested on Arch Linux.

Building needs `git`, `curl`, `patch`, and `dkms`, plus network access to
download the upstream source.

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

A default configuration is installed to `/etc/modprobe.d/hid-magicmouse.conf`,
if one doesn't already exist. You can edit this file to change the default
module parameters, or edit `config/hid-magicmouse.conf` in this repository to
change the defaults for future installations.

> [!IMPORTANT]
> The configuration must be a regular file, not a symlink. If the symlink target
> is not mounted during early boot, kmod will deny-list the module and it will
> not load.

To change settings at runtime without rebooting:

```sh
# Enable scrolling while the mouse is moving, which is disabled by default.
echo 1 | sudo tee /sys/module/hid_magicmouse/parameters/scroll_while_moving
```

Available parameters:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `scroll_while_moving` | `0` | Allow scrolling while the mouse is moving. |
| `scroll_while_clicking` | `0` | Allow scrolling while a button is held. |
| `scroll_acceleration` | `0` | Enable scroll acceleration. |
| `scroll_speed` | `32` | Scroll speed from 0-63, where higher is faster. |
| `emulate_scroll_wheel` | `1` | Enable touch-to-scroll emulation. |
| `emulate_3button` | `1` | Enable middle/right click emulation. |

## Patches

This project applies a series of patches to the upstream Linux
`hid-magicmouse.c` driver, one patch per feature.

```
patches/
  base/hid-magicmouse.c   Upstream source the series is written against.
  base/version            Kernel tag that source came from.
  verified                Upstream versions known to apply cleanly.
  0001-*.patch            One patch per feature, applied in order.
```

The build downloads the upstream `hid-magicmouse.c` for the kernel version it is
building against and merges the series onto it. Line shifts and unrelated
upstream edits are absorbed automatically. Only a change to the same lines a
patch touches needs attention. DKMS repeats this for each kernel it builds. If
the download or merge fails it reuses the last working source, so an upgrade
never leaves you without a driver.

A series works on any kernel it still merges onto, which is usually a range of
releases. Kernels older than the base generally fail, since the driver uses APIs
they do not have.

```sh
make status                                 # The current kernel.
make status KERNEL=7.2.1-arch1-1            # Any other kernel.
make verify KERNEL=7.1.10-arch1-1           # Record one that merges.
```

### Updating for a New Kernel

When the merge can no longer resolve an upstream change, replay the series onto
the new source:

```sh
make rebase
```

Each patch is rebased in turn inside a scratch git repository at `.work/`. A
conflict is attributed to the single patch that caused it, and is resolved with
the usual git tools:

```sh
git -C .work/repo add hid-magicmouse.c
git -C .work/repo rebase --continue
```

Then write the series back:

```sh
make export
```

Some upstream changes cannot be reconciled at all. Tag a release before
rebasing so anyone on an older kernel can still build it, then bump the
version.

### Changing the Driver

Edit a patch by rebasing onto the current base and amending its commit:

```sh
make rebase
git -C .work/repo rebase -i upstream
make export
```

## License

See [LICENSE](LICENSE) for more details.
