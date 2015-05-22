#!/bin/sh

# Build a dd-able image from rootfs and boot directories

## Usage
if [ -z "$MACHINE" ]; then
    echo "Need to set MACHINE"
    exit 1
fi

if [ -z "$IMAGE" ]; then
    echo "Need to set IMAGE"
    exit 1
fi

## Setup variables
MLO=${PWD}/machines/${MACHINE}/MLO
UBOOT=${PWD}/machines/${MACHINE}/u-boot.img
UENV=${PWD}/machines/${MACHINE}/uEnv.txt
ROOTFS=${PWD}/images/${IMAGE}/rootfs.tar.gz

## Run some checks
if [ ! -e ${MLO} ]; then
    echo "No ${MLO} found! Quitting..."
    exit 1
fi
if [ ! -e ${UBOOT} ]; then
    echo "No ${UBOOT} found! Quitting..."
    exit 1
fi
if [ ! -e ${UENV} ]; then
    echo "No ${UENV} found! Quitting..."
    exit 1
fi
if [ ! -e ${ROOTFS} ]; then
    echo "No ${ROOTFS} found! Quitting..."
    exit 1
fi

## We need these tools
QEMUIMG=$(which qemu-img) || { echo "E: You must have qemu-img" && exit 1; }
MKFS=$(which mkfs) || { echo "E: You must have mkfs" && exit 1; }
KPARTX=$(which kpartx) || { echo "E: You must have kpartx" && exit 1; }
SFDISK=$(which sfdisk) || { echo "E: You must have sfdisk" && exit 1; }
LOSETUP=$(which losetup) || { echo "E: You must have losetup" && exit 1; }

## Clean up the loop devices
sudo losetup -D

## Prepare mount point
sudo umount -f /mnt &>/dev/null

echo "I: Creating a raw image file"
IMGFILE=${MACHINE}-${IMAGE}.img
${QEMUIMG} create -f raw ${IMGFILE} 4G

echo "I: Partition the device"
{
echo 128,130944,0x0C,*
echo 131072,,,-
} | sudo ${SFDISK} -D -uS -H 255 -S 63 ${IMGFILE} --force

LOOPDEV=` sudo ${KPARTX} -av ${IMGFILE} | sed -n 1p | awk '{print $3}' | cut -c 1-5`
LOOPDEV_BOOT=/dev/mapper/${LOOPDEV}p1
LOOPDEV_ROOT=/dev/mapper/${LOOPDEV}p2

echo "I: Set up the boot partition"
sudo ${MKFS}.vfat -F 32 -n boot ${LOOPDEV_BOOT}
sudo mount ${LOOPDEV_BOOT} /mnt
sudo cp -v ${MLO} ${UBOOT} ${UENV} /mnt/
sync
sudo umount /mnt

echo "I: Set up the rootfs partition"
sudo ${MKFS}.ext4 -L rootfs ${LOOPDEV_ROOT}
sudo mount ${LOOPDEV_ROOT} /mnt
sudo tar xaf ${ROOTFS} --strip-components=1 -C /mnt
sync
sudo umount /mnt

sudo ${KPARTX} -dv ${IMGFILE}

echo "I: Done"
