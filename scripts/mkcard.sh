#!/bin/bash
if [ $# -lt 1 ]; then
    echo "Usage: $0 <drive>"
    exit 1
fi

if [ -z "$MACHINE" ]; then
    echo "Need to set MACHINE"
    exit 1
fi

if [ -z "$IMAGE" ]; then
    echo "Need to set IMAGE"
    exit 1
fi

## Setup variables
DRIVE=$1
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

echo -n "All data on "$1" now will be destroyed! Continue? [y/n]: "
read ans
if [ ! $ans == 'y' ]; then
        exit
fi

echo "[Unmounting all existing partitions on the device ]"
sudo umount ${DRIVE}* &> /dev/null

## Okay...to business
echo "[Partitioning ${DRIVE}...]"
sudo dd if=/dev/zero of=$DRIVE bs=1024 count=1024
# 64MB VFAT boot partition, Remainder is EXT4 rootfs partition
# Sector size is 512-bytes
{
echo 128,130944,0x0C,*
echo 131072,,,-
} | sudo sfdisk --force -D -uS -H 255 -S 63 $DRIVE &> /dev/null

echo "[Making boot partition...]"
if [ -b ${1}1 ]; then
    sudo mkfs.vfat -F 32 -n boot "$1"1 &> /dev/null
    sudo mount "$1"1 /mnt
else
    sudo mkfs.vfat -F 32 -n boot "$1"p1 &> /dev/null
    sudo mount "$1"p1 /mnt
fi
sudo cp -v ${MLO} ${UBOOT} ${UENV} /mnt/
sudo umount /mnt

echo "[Making rootfs partition...]"
if [ -b ${1}2 ]; then
    sudo mkfs.ext4 -L rootfs "$1"2 &> /dev/null
    sudo mount "$1"2 /mnt
else
    sudo mkfs.ext4 -L rootfs "$1"p2 &> /dev/null
    sudo mount "$1"p2 /mnt
fi
sudo tar xaf ${ROOTFS} --strip-components=1 -C  /mnt &> /dev/null
sync
sudo umount /mnt

echo "[Done]"
