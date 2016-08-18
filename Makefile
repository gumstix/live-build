#/usr/bin/make -f
image_path := $(PWD)/images
machine_path := $(PWD)/machines

machines := $(shell ls $(machine_path)*)
images := $(shell ls $(image_path)*)
ifeq ($(strip $(MACHINE)),)
    $(error MACHINE variable not set. Usage: make MACHINE=<$(machines)> IMAGE=<$(images)>)
endif
ifeq ($(strip $(IMAGE)),)
    $(error IMAGE variable not set. Usage: make MACHINE=<$(machines)> IMAGE=<$(images)>)
endif
image_path := $(image_path)/$(IMAGE)
machine_path := $(machine_path)/$(MACHINE)

#================================= CONFIG ======================================
ROOTFS := $(image_path)/rootfs.tar.gz
MLO := $(machine_path)/MLO
UBOOT := $(machine_path)/u-boot.img
UENV := $(machine_path)/uEnv.txt
KERNEL := vmlinux

CROSS_COMPILE := arm-linux-gnueabihf-

UBOOT_GIT := git://github.com/gumstix/u-boot.git
UBOOT_SRC_DIR := $(PWD)/u-boot
UBOOT_BRANCH := v2015.07

UBOOT_CONFIG_overo := omap3_overo_defconfig
UBOOT_CONFIG_duovero := duovero_defconfig
UBOOT_CONFIG_pepper := pepper_defconfig

LINUX_GIT := git://github.com/gumstix/linux.git
LINUX_SRC_DIR := $(PWD)/linux
LINUX_BRANCH := yocto-v3.18.y

# don't pass down MACHINE---linux doesn't like it
MAKEOVERRIDES =
# prevent built-in rules---we're not using them
.SUFFIXES:

.PHONY: all uboot clean-uboot linux clean-linux rootfs clean-rootfs
all: $(ROOTFS) $(MLO) $(UBOOT) $(UENV)
clean: clean-uboot clean-linux clean-rootfs

#================================ ROOTFS ======================================
rootfs: $(ROOTFS)
$(ROOTFS): $(KERNEL)
	@(cd $(image_path) && lb config)
	@rm -f *-dbg_*.deb
	@cp *.deb $(image_path)/config/packages.chroot/
	@(cd $(image_path) && sudo lb build)
	@mv $(image_path)/binary-tar.tar.gz $(ROOTFS)

clean-rootfs:
	@(cd $(image_path) && sudo lb clean)
	@-rm -f $(ROOTFS)

#================================= UBOOT ======================================
UBOOT_CONFIG := $(UBOOT_CONFIG_$(MACHINE))
ifeq ($(strip $(UBOOT_CONFIG)),)
    $(error No known u-boot configuration for $(MACHINE))
endif

uboot: $(MLO) $(UBOOT)
$(MLO) $(UBOOT): u-boot-output.intermediate

# Check-out u-boot (naively assume that if the directory exists, u-boot is checked out)
$(UBOOT_SRC_DIR):
	@git clone $(UBOOT_GIT) --depth 1 -b $(UBOOT_BRANCH) $(UBOOT_SRC_DIR)

# configure u-boot
$(UBOOT_SRC_DIR)/.config: | $(UBOOT_SRC_DIR)
	@$(MAKE) -C $(UBOOT_SRC_DIR) CROSS_COMPILE=$(CROSS_COMPILE) $(UBOOT_CONFIG)

# if any file in the u-boot directory changes, build
.INTERMEDIATE: u-boot-output.intermediate
u-boot-output.intermediate: $(UBOOT_SRC_DIR)/.config $(shell find $(UBOOT_SRC_DIR) -type f 2>/dev/null)
	@$(MAKE) -C $(UBOOT_SRC_DIR) CROSS_COMPILE=$(CROSS_COMPILE)
	@cp $(UBOOT_SRC_DIR)/MLO $(MLO)
	@cp $(UBOOT_SRC_DIR)/u-boot.img $(UBOOT)

clean-uboot:
	@-$(MAKE) -C $(UBOOT_SRC_DIR) CROSS_COMPILE=$(CROSS_COMPILE) distclean
	@-rm -f $(MLO) $(UBOOT)

#================================= LINUX ======================================
# Check-out linux (naively assume that if the directory exists, linux is checked out)
$(LINUX_SRC_DIR):
	@git clone $(LINUX_GIT) --depth 1 -b $(LINUX_BRANCH) $(LINUX_SRC_DIR)

# Configure with a <MACHINE>_defconfig from the MACHINE directory
$(LINUX_SRC_DIR)/.config: $(machine_path)/defconfig | $(LINUX_SRC_DIR)
	@cp $< $@
	$(MAKE) -C $(LINUX_SRC_DIR) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) oldconfig

#FIXME: Use vmlinux as a proxy for a completed build.  Really we want...
#linux-headers-3.17.8-custom-g3a4e592_3.17.8-custom-g3a4e592-1_armhf.deb
#linux-image-3.17.8-custom-g3a4e592_3.17.8-custom-g3a4e592-1_armhf.deb
#linux-image-3.17.8-custom-g3a4e592-dbg_3.17.8-custom-g3a4e592-1_armhf.deb
#linux-libc-dev_3.17.8-custom-g3a4e592-1_armhf.deb
$(KERNEL): $(LINUX_SRC_DIR)/.config $(shell find $(LINUX_SRC_DIR) -type f 2>/dev/null)
	@$(MAKE) -C $(LINUX_SRC_DIR) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) KBUILD_DEBARCH=armhf deb-pkg LOCALVERSION=""
	@cp $(LINUX_SRC_DIR)/vmlinux $(KERNEL)

linux: $(KERNEL)

clean-linux:
	@-rm -f linux-*.deb
	@-$(MAKE) -C $(LINUX_SRC_DIR) ARCH=arm CROSS_COMPILE=$(CROSS_COMPILE) mrproper
