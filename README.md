# Custom EDK2 for Radxa Orin Nano products

This instruction is only needed if you want to factory reset the SPI flash on the Radxa Orin Nano product's included NVIDIA Jetson Orin Nano module.

Radxa Orin Nano products are factory flashed with a custom EDK2, that can support booting official NVIDIA Jetson Orin Nano SD card image on other storage mediums. Tested with:

* USB storage device
* M.2 NVMe SSD

When using the official SD card image, the custom EDK2 will try finding the first `APP` partition as the rootfs. This means you should not connect multiple storage devices with the official image flashed on it, as the system may not use the correct rootfs partition to boot.

## Background

### Radxa Orin C200

NVIDIA Jetson Orin Nano Developer Kit (NDK) has the following hardware difference when compared to Radxa Orin C200:

* NDK contains microSD slot on the module, while C200 uses production module with doesn't have this part populated.

Additionally, there is no SDMMC signal exposed on the Jetson SODIMM connector. However, the official SD card image is hardcoded with `/dev/mmcblk1p1` as rootfs.

This means the following changes are required to boot unmodified NVIDIA SD card image on other mediums:

* EDK2 should patch kernel cmdline if it detects the invalid rootfs.

### Radxa Airbox Orin

Radxa Airbox Orin has some additional changes compared to Radxa Orin C200:

* USB 3.0 hub is gone. Both USB 3.0 Type-A ports are connected directly to the module.
* GPIO01, GPIO04, and GPIO11 are connected to a RGB LED.
* GPIO09 enables the USB sound card.
* GPIO13 enables the speaker amplifier.

The embedded device tree and MB1 BCT Pinmux have been updated to support those features.

## Development

### Build dependency

Please check [the official NVIDIA build guide](https://github.com/NVIDIA/edk2-nvidia/wiki/Build-with-docker#install-docker).

Additionally, the Linux kernel header should be installed on your system.

NixOS users can run `nix develop` (Flake required) to have a local shell with Linux header configured.


### Configuration

Users need to define the following variables before building:

`PRODUCT` refers to the carrier board, which should be one of the following:
- `c200`
- `airbox-orin`

`BOARDSKU` refers to the module number, which should be one of the following:
- `0000`
- `0001`
- `0003`
- `0004`
- `0005`

The meanings of the possible values of `BOARDSKU`:
```
0000 - Jetson Orin NX 16GB
0001 - Jetson Orin NX 8GB
0003 - Jetson Orin Nano 8GB
0004 - Jetson Orin Nano 4GB
0005 - Jetson Orin Nano 8GB with SD card slot
```

For more information, see the [Nvidia Developer Guide](https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/index.html#devices-supported-by-this-document).

### Build

Please run following commands:

```
make build
```

The generated binary is located under `$(PRODUCT)/images/uefi_Jetson_RELEASE.bin`.

### Flash

First, boot the device to [force recovery mode](https://developer.nvidia.com/embedded/learn/jetson-agx-orin-devkit-user-guide/howto.html#force-recovery-mode). Then run following commands:

```
# Update EDK2
make flash

# Pinmux needs to be updated for Airbox Orin's status LED
make flash_bct
```

If you want to update the entire SPI flash, please run:

```
make flash_spi
```
