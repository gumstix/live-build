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

## we must be root
[ $(whoami) = "root" ] || { echo "E: You must be root" && exit 1; }

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

echo "I: Creating a raw image file"
IMGFILE=${MACHINE}-${IMAGE}.img
qemu-img create -f raw ${IMGFILE} 4G

echo "I: Partition the device"
{
echo 128,130944,0x0C,*
echo 131072,,,-
} | sudo /sbin/sfdisk -D -uS -H 255 -S 63 ${IMGFILE} --force

LOOPDEV=` sudo kpartx -av ${IMGFILE} | sed -n 1p | awk '{print $3}' | cut -c 1-5`
LOOPDEV_BOOT=/dev/mapper/${LOOPDEV}p1
LOOPDEV_ROOT=/dev/mapper/${LOOPDEV}p2

echo "I: Set up the boot partition"
sudo mkfs.vfat -F 32 -n boot ${LOOPDEV_BOOT}
sudo mount ${LOOPDEV_BOOT} /mnt
cp -v ${MLO} ${UBOOT} ${UENV} /mnt/
sync
sudo umount /mnt

echo "I: Set up the rootfs partition"
sudo mkfs.ext4 -L rootfs ${LOOPDEV_ROOT}
sudo mount ${LOOPDEV_ROOT} /mnt
sudo tar xaf ${ROOTFS} --strip-components=1 -C /mnt
sync
sudo umount /mnt

sudo kpartx -dv ${IMGFILE}

echo "I: Creating a compressed image"
gzip -9 ${IMGFILE}

echo "I: Done"
