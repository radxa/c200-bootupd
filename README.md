# Custom EDK2 for Radxa Orin C200

This instruction is only needed if you want to factory reset the SPI flash on the C200's included NVIDIA Jetson Orin Nano module.

Radxa Orin C200 is factory flashed with a custom EDK2, that can support booting official NVIDIA Jetson Orin Nano SD card image on other storage mediums. Tested with:

* USB storage device
* M.2 NVMe SSD

When using the official SD card image, the custom EDK2 will try finding the first `APP` partition as the rootfs. This means you should not connect multiple storage devices with the official image flashed on it, as the system may not use the correct rootfs partition to boot.

## Background

NVIDIA Jetson Orin Nano Developer Kit (NDK) has the following hardware difference when compared to Radxa Orin C200:

* NDK contains microSD slot on the module, while C200 uses production module with doesn't have this part populated.

Additionally, there is no SDMMC signal exposed on the Jetson SODIMM connector. However, the official SD card image is hardcoded with `/dev/mmcblk1p1` as rootfs.

This means the following changes are required to boot unmodified NVIDIA SD card image on other mediums:

* EDK2 should patch kernel cmdline if it detects the invalid rootfs.

## Development

### Build dependency

Please check [the official NVIDIA build guide](https://github.com/NVIDIA/edk2-nvidia/wiki/Build-with-docker#install-docker).

Additionally, the Linux kernel header should be installed on your system.

NixOS users can run `nix develop` (Flake required) to have a local shell with Linux header configured.

### Build

Please run following commands:

```
make build
```

The generated binary is located under `c200/images/uefi_Jetson_RELEASE.bin`.

### Flash

First, boot the device to [force recovery mode](https://developer.nvidia.com/embedded/learn/jetson-agx-orin-devkit-user-guide/howto.html#force-recovery-mode). Then run following commands:

```
make flash
# Other products can be specified with PRODUCT variable
```

Please be aware that this only updates the EDK2 part of the QSPI firmware.  
The custom device tree requires different pinmux configuration, which is not part of the EDK2.

If you want to completely update the whole SPI, please run:

```
make flash_spi
```
