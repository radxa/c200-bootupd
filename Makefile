.PHONY: all build flash flash_spi clean distclean

PROFILE ?= Jetson
# or JetsonMinimal

VARIANT ?= RELEASE
# or DEBUG

BUILD_OUTPUT := c200/images/uefi_$(PROFILE)_$(VARIANT).bin

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
	cd c200/edk2-nvidia && git am --keep-cr ../../patches/edk2-nvidia/*

$(BUILD_OUTPUT): c200/edk2-nvidia/Platform/NVIDIA/$(PROFILE)/build.sh c200/edk2-nvidia/Silicon/NVIDIA/Drivers/TegraPlatformBootManager/TegraPlatformBootManagerDxe.c
	cd c200 && \
	../edk2_docker edk2-nvidia/Platform/NVIDIA/$(PROFILE)/build.sh \
		--init-defconfig edk2-nvidia/Platform/NVIDIA/$(PROFILE)/Jetson.defconfig

build: $(BUILD_OUTPUT)

Jetson_Linux_R36.4.3_aarch64.tbz2:
	wget https://developer.download.nvidia.com/embedded/L4T/r36_Release_v4.3/release/$@

Linux_for_Tegra/flash.sh: Jetson_Linux_R36.4.3_aarch64.tbz2
	tar xmf $<

.PHONY: Linux_for_Tegra/bootloader/uefi_jetson.bin
Linux_for_Tegra/bootloader/uefi_jetson.bin: c200/images/uefi_Jetson_$(VARIANT).bin
	cp $< $@

Linux_for_Tegra/bootloader/uefi_jetson_minimal.bin: c200/images/uefi_JetsonMinimal_$(VARIANT).bin
	cp $< $@

flash: Linux_for_Tegra/bootloader/$(BOOTLOADER) Linux_for_Tegra/flash.sh
	cd Linux_for_Tegra && \
	sudo ./flash.sh -k A_cpu-bootloader p3768-0000-p3767-0000-a0-qspi internal

flash_spi: Linux_for_Tegra/bootloader/$(BOOTLOADER) Linux_for_Tegra/flash.sh
	cd Linux_for_Tegra && \
	sudo ./flash.sh p3768-0000-p3767-0000-a0-qspi internal

clean:
	rm -f c200/images/uefi_Jetson*_*.bin

distclean: clean
	./edk2_docker edkrepo clean
	./edk2_docker edkrepo manifest-repos remove nvidia
	rm -rf c200/ Linux_for_Tegra Jetson_Linux_R36.4.3_aarch64.tbz2

Linux_for_Tegra/source/kernel/kernel-jammy-src/Makefile:
	cd Linux_for_Tegra/source/ && \
	./source_sync.sh -k jetson_36.4.3

dtbs:
	$(MAKE) -C Linux_for_Tegra/source nvidia-dtbs

dtbs-clean:
	$(MAKE) -C Linux_for_Tegra/source nvidia-dtbs-clean
