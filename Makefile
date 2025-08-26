.PHONY: all build flash flash_spi clean distclean

PRODUCT ?= c200
# or airbox-orin

PROFILE ?= Jetson
# or JetsonMinimal

VARIANT ?= RELEASE
# or DEBUG

# 0000 - Jetson Orin NX 16GB
# 0001 - Jetson Orin NX 8GB
# 0003 - Jetson Orin Nano 8GB
# 0004 - Jetson Orin Nano 4GB
# 0005 - Jetson Orin Nano 8GB with SD card slot
# See https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/index.html#devices-supported-by-this-document
BOARDSKU ?= 0001

# Variables for the commonly used paths.
SRC := $(CURDIR)
PATCHES := $(SRC)/patches

# After compiling the modified dts file, the dtb file will appear under
# `Linux_for_Tegra/source/kernel-devicetree/generic-dts/`, we need to put the
# dtb file under `Linux_for_Tegra/kernel/dtb/` where it will get picked up by
# the `flash.sh` script.
# See https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/HR/JetsonModuleAdaptationAndBringUp/JetsonOrinNxNanoSeries.html#updating-dtb-files
DTS_FILE := tegra234-p3768-0000+p3767-$(BOARDSKU)-nv-super.dts
DTS_PATH := Linux_for_Tegra/source/hardware/nvidia/t23x/nv-public/nv-platform/$(DTS_FILE)
DTB_FILE := $(DTS_FILE:%.dts=%.dtb)
DTB_OUTPUT := Linux_for_Tegra/source/kernel-devicetree/generic-dts/dtbs/$(DTB_FILE)
DTB_DEST := Linux_for_Tegra/kernel/dtb/$(DTB_FILE)

BUILD_OUTPUT := c200/images/uefi_$(PROFILE)_$(VARIANT).bin

# The environment variables KERNEL_HEADERS is needed to compile the dtbs.
# See https://docs.nvidia.com/jetson/archives/r36.4.4/DeveloperGuide/SD/Kernel/ KernelCustomization.html#building-the-dtbs
KERNEL_HEADERS := $(SRC)/Linux_for_Tegra/source/kernel/kernel-jammy-src
ENV_VARS := KERNEL_HEADERS=$(KERNEL_HEADERS)

ifeq ($(PROFILE), Jetson)
BOOTLOADER := uefi_jetson.bin
else ifeq ($(PROFILE), JetsonMinimal)
BOOTLOADER := uefi_jetson_minimal.bin
else
$(error Unrecognized PROFILE "$(PROFILE)")
endif

all: build

c200/edk2-nvidia/Platform/NVIDIA/$(PROFILE)/build.sh c200/edk2-nvidia/Silicon/NVIDIA/Drivers/TegraPlatformBootManager/TegraPlatformBootManagerDxe.c &:
	rm -rf c200
	./edk2_docker init_edkrepo_conf
	./edk2_docker edkrepo manifest-repos add nvidia https://github.com/NVIDIA/edk2-edkrepo-manifest.git main nvidia || true
	./edk2_docker edkrepo clone c200 NVIDIA-Platforms r36.4.3
	cd c200/edk2-nvidia && git am --keep-cr $(PATCHES)/edk2-nvidia/*

$(BUILD_OUTPUT): c200/edk2-nvidia/Platform/NVIDIA/$(PROFILE)/build.sh c200/edk2-nvidia/Silicon/NVIDIA/Drivers/TegraPlatformBootManager/TegraPlatformBootManagerDxe.c
	cd c200 && \
	../edk2_docker edk2-nvidia/Platform/NVIDIA/$(PROFILE)/build.sh \
		--init-defconfig edk2-nvidia/Platform/NVIDIA/$(PROFILE)/Jetson.defconfig

build: $(BUILD_OUTPUT) \
$(DTB_DEST) \
Linux_for_Tegra/bootloader/$(BOOTLOADER) \
Linux_for_Tegra/bootloader/generic/BCT/tegra234-mb1-bct-pinmux-p3767-dp-a03.dtsi \
Linux_for_Tegra/bootloader/tegra234-mb1-bct-gpio-p3767-dp-a03.dtsi \
Linux_for_Tegra/bootloader/generic/BCT/tegra234-mb1-bct-padvoltage-p3767-dp-a03.dtsi

Jetson_Linux_R36.4.3_aarch64.tbz2:
	wget https://developer.download.nvidia.com/embedded/L4T/r36_Release_v4.3/release/$@

Linux_for_Tegra/flash.sh Linux_for_Tegra/source/source_sync.sh &: Jetson_Linux_R36.4.3_aarch64.tbz2
	tar xmf $<

.PHONY: Linux_for_Tegra/bootloader/uefi_jetson.bin
Linux_for_Tegra/bootloader/uefi_jetson.bin: c200/images/uefi_Jetson_$(VARIANT).bin
	cp $< $@

Linux_for_Tegra/bootloader/uefi_jetson_minimal.bin: c200/images/uefi_JetsonMinimal_$(VARIANT).bin
	cp $< $@

# The script `flash.sh` will select the dtb file configured by the file
# jetson-orin-nano-devkit-super.conf
flash: build Linux_for_Tegra/flash.sh
	cd Linux_for_Tegra && \
	sudo ./flash.sh --qspi-only -k A_cpu-bootloader jetson-orin-nano-devkit-super internal

flash_bct: build Linux_for_Tegra/flash.sh
	cd Linux_for_Tegra && \
	sudo ./flash.sh -k A_MB1_BCT p3768-0000-p3767-0000-a0-qspi internal

flash_spi: build Linux_for_Tegra/flash.sh
	cd Linux_for_Tegra && \
	sudo ./flash.sh p3768-0000-p3767-0000-a0-qspi internal

clean:
	rm -f c200/images/uefi_Jetson*_*.bin
	[ -e Linux_for_Tegra/source/Makefile ] && \
		$(ENV_VARS) $(MAKE) -C Linux_for_Tegra/source nvidia-dtbs-clean

distclean: clean
	./edk2_docker edkrepo clean
	./edk2_docker edkrepo manifest-repos remove nvidia
	rm -rf c200/ Linux_for_Tegra Jetson_Linux_R36.4.3_aarch64.tbz2

$(DTS_PATH): Linux_for_Tegra/source/source_sync.sh
	cd Linux_for_Tegra/source/ && \
	./source_sync.sh -k jetson_36.4.3
	# Apply the patches if the patch directory exists
	if [ -d $(PATCHES)/t23x-public-dts/$(PRODUCT) ]; then \
		cd Linux_for_Tegra/source/hardware/nvidia/t23x/nv-public;  \
		git am $(PATCHES)/t23x-public-dts/$(PRODUCT)/*; \
	fi

# Our KERNEL_HEADERS points to a source directory rather than an exported
# headers directory, so we need to compile the scripts to build dtc.
$(DTB_OUTPUT): $(DTS_PATH) scripts Linux_for_Tegra/source/hardware/nvidia/t23x/nv-public/nv-platform/tegra234-dcb-p3737-0000-p3701-0000.dtsi
	$(ENV_VARS) $(MAKE) -C Linux_for_Tegra/source nvidia-dtbs

.PHONY: scripts
scripts:
	$(ENV_VARS) make -C Linux_for_Tegra/source/kernel/kernel-jammy-src ARCH=arm64 defconfig scripts

.PHONY: $(DTB_DEST)
$(DTB_DEST): $(DTB_OUTPUT)
	cp $< $@

.PHONY: Linux_for_Tegra/bootloader/generic/BCT/tegra234-mb1-bct-pinmux-p3767-dp-a03.dtsi
Linux_for_Tegra/bootloader/generic/BCT/tegra234-mb1-bct-pinmux-p3767-dp-a03.dtsi: pinmux/$(PRODUCT)/tegra234-mb1-bct-pinmux-p3767-dp-a03.dtsi
	cp $< $@

.PHONY: Linux_for_Tegra/bootloader/tegra234-mb1-bct-gpio-p3767-dp-a03.dtsi
Linux_for_Tegra/bootloader/tegra234-mb1-bct-gpio-p3767-dp-a03.dtsi: pinmux/$(PRODUCT)/tegra234-mb1-bct-gpio-p3767-dp-a03.dtsi
	cp $< $@

.PHONY: Linux_for_Tegra/bootloader/generic/BCT/tegra234-mb1-bct-padvoltage-p3767-dp-a03.dtsi
Linux_for_Tegra/bootloader/generic/BCT/tegra234-mb1-bct-padvoltage-p3767-dp-a03.dtsi: pinmux/$(PRODUCT)/tegra234-mb1-bct-padvoltage-p3767-dp-a03.dtsi
	cp $< $@

.PHONY: Linux_for_Tegra/source/hardware/nvidia/t23x/nv-public/nv-platform/tegra234-dcb-p3737-0000-p3701-0000.dtsi
Linux_for_Tegra/source/hardware/nvidia/t23x/nv-public/nv-platform/tegra234-dcb-p3737-0000-p3701-0000.dtsi: pinmux/$(PRODUCT)/tegra234-dcb-p3737-0000-p3701-0000.dtsi
	cp $< $@
