.PHONY: all build flash flash_spi clean distclean

PRODUCT ?= c200
# or airbox-orin

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

build: $(BUILD_OUTPUT) \
Linux_for_Tegra/bootloader/$(BOOTLOADER) \
Linux_for_Tegra/kernel/dtb/tegra234-p3768-0000+p3767-0005-nv.dtb \
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

flash: build Linux_for_Tegra/flash.sh
	cd Linux_for_Tegra && \
	sudo ./flash.sh -k A_cpu-bootloader p3768-0000-p3767-0000-a0-qspi internal

flash_spi: build Linux_for_Tegra/flash.sh
	cd Linux_for_Tegra && \
	sudo ./flash.sh p3768-0000-p3767-0000-a0-qspi internal

clean:
	rm -f c200/images/uefi_Jetson*_*.bin
	[ -e Linux_for_Tegra/source/Makefile ] && \
		$(MAKE) -C Linux_for_Tegra/source nvidia-dtbs-clean

distclean: clean
	./edk2_docker edkrepo clean
	./edk2_docker edkrepo manifest-repos remove nvidia
	rm -rf c200/ Linux_for_Tegra Jetson_Linux_R36.4.3_aarch64.tbz2

Linux_for_Tegra/source/hardware/nvidia/t23x/nv-public/nv-platform/tegra234-p3768-0000+p3767-0005-nv.dts: Linux_for_Tegra/source/source_sync.sh
	cd Linux_for_Tegra/source/ && \
	./source_sync.sh -k jetson_36.4.3
	cd Linux_for_Tegra/source/hardware/nvidia/t23x/nv-public && git am ../../../../../../patches/t23x-public-dts/$(PRODUCT)/*

Linux_for_Tegra/source/kernel-devicetree/generic-dts/dtbs/tegra234-p3768-0000+p3767-0005-nv.dtb: Linux_for_Tegra/source/hardware/nvidia/t23x/nv-public/nv-platform/tegra234-p3768-0000+p3767-0005-nv.dts
	$(MAKE) -C Linux_for_Tegra/source nvidia-dtbs

.PHONY: Linux_for_Tegra/kernel/dtb/tegra234-p3768-0000+p3767-0005-nv.dtb
Linux_for_Tegra/kernel/dtb/tegra234-p3768-0000+p3767-0005-nv.dtb: Linux_for_Tegra/source/kernel-devicetree/generic-dts/dtbs/tegra234-p3768-0000+p3767-0005-nv.dtb
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
