#!/usr/bin/env bash

# This script is based on:
# https://itnext.io/how-to-create-a-custom-ubuntu-live-from-scratch-dd3b3f213f81

# Parameters - adjust for your needs
ROOT_DIR="$HOME/live-ubuntu-from-scratch"
BUILD_NAME=STERO
BUILD_DATE=20201009
BUILD_NUM=1
# Path to https://github.com/Tomas-M/linux-live.git:
LINUX_LIVE_PACKAGE_DIR="$HOME"/code/linux-live
KERNEL="4.15.0-118-generic"

SKIP_INITRAMFS_BUILD=true
SKIP_SQUASHFS_BUILD=true

# Useful variables
OUTPUT_IMAGE_NAME="ubuntu-18-04-${BUILD_DATE}${BUILD_NUM}.img"
SPLIT_SIZE_MB=500
UNIQUE_FILE="ubuntu_${BUILD_NAME}_${BUILD_DATE}${BUILD_NUM}"
DISK_NAME="Ubuntu 18.04-${BUILD_NAME}-${BUILD_DATE}_${BUILD_NUM}"

# Write config for linux-live
cat <<EOF > "${LINUX_LIVE_PACKAGE_DIR}/config"
LIVEKITNAME="${BUILD_NAME}${BUILD_DATE}${BUILD_NUM}"

# Kernel file, will be copied to your Live Kit
# Your kernel must support aufs and squashfs. Debian Jessie's kernel is ready
# out of the box.
VMLINUZ=/vmlinuz

# Kernel version. Change it to "3.2.28" for example, if you are building
# Live Kit with a different kernel than the one you are actually running
KERNEL=${KERNEL}

# List of directories for root filesystem
# No subdirectories are allowed, no slashes,
# so You can't use /var/tmp here for example
# Exclude directories like proc sys tmp
MKMOD="bin etc home lib lib64 opt root sbin srv usr var"

# If you require network support in initrd, for example to boot over
# PXE or to load data using 'from' boot parameter from a http server,
# you will need network modules included in your initrd.
# This is disabled by default since most people won't need it.
# To enable, set to true
NETWORK=false

# Temporary directory to store livekit filesystem
LIVEKITDATA=/tmp/\$LIVEKITNAME-data-\$\$

# Bundle extension, for example 'sb' for .sb extension
BEXT=squashfs

# Directory with kernel .ko modules, can be different in some distros
LMK="lib/modules/\$KERNEL"
EOF

. ${LINUX_LIVE_PACKAGE_DIR}/config

# Here we assume, the root filesystem is already created
# in folder $ROOT_DIR/chroot
if [ ! -d "$ROOT_DIR/chroot/etc" ]; then
   echo "ERROR: Could not find $ROOT_DIR/chroot/etc."
   echo "The root filesystem should be in $ROOT_DIR/chroot"
   exit 1
fi

# Add pre-login welcome message
cat <<EOF > "$ROOT_DIR/issue"
Ubuntu 18.04.5 LTS ${BUILD_NAME} Live build ${BUILD_DATE}${BUILD_NUM}

Username is: ubuntu
Password is empty

To run graphical interface type:
startx /usr/bin/xfce4-session

EOF
sudo mv "$ROOT_DIR/issue" "$ROOT_DIR/chroot/etc/issue"

# Create directories for destination filesystem
cd "$ROOT_DIR"
mkdir -p image/{casper,isolinux,install,boot}

# Copy some stuff
sudo cp chroot/boot/vmlinuz-**-**-generic image/casper/vmlinuz
#sudo cp chroot/boot/initrd.img-**-**-generic image/casper/initrd

#sudo cp /boot/memtest86+.bin image/install/memtest86
wget --progress=dot https://www.memtest86.com/downloads/memtest86-usb.zip -O image/install/memtest86-usb.zip
unzip -p image/install/memtest86-usb.zip memtest86-usb.img > image/install/memtest86
rm image/install/memtest86-usb.zip

#exit 0

# Build initramfs image
if [ -z "$SKIP_INITRAMFS_BUILD" ]; then
  echo "Building intramfs image..."
  cd $LINUX_LIVE_PACKAGE_DIR/initramfs
  INITRAMFS=$(./initramfs_create)
  cd "$ROOT_DIR/image"
  if [ "$INITRAMFS" != "" ]; then
     #mv "$INITRAMFS" boot/initrfs.img
     mv "$INITRAMFS" casper/initrd
  fi
  cd "$ROOT_DIR"
fi

#cp /usr/lib/ISOLINUX/isolinux.bin image/isolinux/
#cp /usr/lib/syslinux/modules/bios/ldlinux.c32 image/isolinux/ # for syslinux 5.00 and newer
#cp /boot/memtest86+.bin image/install/memtest

# Create base point access file for grub
# Set some unique name, so that GRUB can find this USB stick among multiple other drives.
# Later, we search for this file from our GRUB.
#touch image/$UNIQUE_FILE
#touch image/ubuntu

# Write GRUB configuration
cat <<EOF > image/isolinux/grub.cfg

pager=1
regexp --set=root \(([^\(\)])+\) \$cmdpath
regexp --set=TEST_VAR \(([^\(\)])+\) \$cmdpath

insmod all_video

set default="0"
set timeout=30

menuentry "Run Ubuntu 18.04 ${BUILD_NAME} build ${BUILD_DATE}${BUILD_NUM} Live" {
   linux /casper/vmlinuz boot=casper quiet splash ---
   initrd /casper/initrd
}

menuentry "Check disc for defects" {
   linux /casper/vmlinuz boot=casper integrity-check quiet splash ---
   initrd /casper/initrd
}

menuentry "Test memory Memtest86+ (BIOS)" {
   linux16 /install/memtest86
}

menuentry "Test memory Memtest86 (UEFI, long load time)" {
   insmod part_gpt
   insmod search_fs_uuid
   insmod chain
   loopback loop /install/memtest86
   chainloader (loop,gpt1)/efi/boot/BOOTX64.efi
}
EOF

FILESYSTEM_DIR=image/"${LIVEKITNAME}"
mkdir -p image/"${LIVEKITNAME}"

# Create manifests
#sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee image/casper/filesystem.manifest
#sudo cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
#sudo sed -i '/ubiquity/d' image/casper/filesystem.manifest-desktop
#sudo sed -i '/casper/d' image/casper/filesystem.manifest-desktop
#sudo sed -i '/discover/d' image/casper/filesystem.manifest-desktop
#sudo sed -i '/laptop-detect/d' image/casper/filesystem.manifest-desktop
#sudo sed -i '/os-prober/d' image/casper/filesystem.manifest-desktop

sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee "${FILESYSTEM_DIR}"/filesystem.manifest
sudo cp -v "${FILESYSTEM_DIR}"/filesystem.manifest "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
sudo sed -i '/casper/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
sudo sed -i '/discover/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
sudo sed -i '/laptop-detect/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
sudo sed -i '/os-prober/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop

# Create squashfs
if [ -z "$SKIP_SQUASHFS_BUILD" ]; then
   #sudo mksquashfs chroot image/casper/filesystem.squashfs
   sudo mksquashfs chroot "${FILESYSTEM_DIR}"/filesystem.squashfs
fi

# Write filesystem size before compression
printf $(sudo du -sx --block-size=1 chroot | cut -f1) > image/casper/filesystem.size

# Write disk defines
cat <<EOF > image/README.diskdefines
#define DISKNAME  $DISK_NAME
#define TYPE  binary
#define TYPEbinary  1
#define ARCH  amd64
#define ARCHamd64  1
#define DISKNUM  1
#define DISKNUM1  1
#define TOTALNUM  0
#define TOTALNUM0  1
EOF

# Create ISO Image for a LiveCD (BIOS + UEFI)
cd "$ROOT_DIR/image"

# Create a grub UEFI image
grub-mkstandalone \
   --format=x86_64-efi \
   --output=isolinux/bootx64.efi \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=isolinux/grub.cfg"

# Create a FAT16 UEFI boot disk image containing the EFI bootloader
(
   cd isolinux && \
   dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
   sudo mkfs.vfat efiboot.img && \
   LC_CTYPE=C mmd -i efiboot.img efi efi/boot && \
   LC_CTYPE=C mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
)

# Create a grub BIOS image
grub-mkstandalone \
   --format=i386-pc \
   --output=isolinux/core.img \
   --install-modules="linux16 linux normal iso9660 biosdisk memdisk search tar ls regexp" \
   --modules="linux16 linux normal iso9660 biosdisk search regexp" \
   --locales="" \
   --fonts="" \
   "boot/grub/grub.cfg=isolinux/grub.cfg"

# Combine a bootable grub cdboot.img
cat /usr/lib/grub/i386-pc/cdboot.img isolinux/core.img > isolinux/bios.img

#mkdir "$ROOT_DIR/image/.disk"
#cd "$ROOT_DIR/image/.disk"
#touch base_installable
#echo "full_cd/single" > cd_type
#echo "Ubuntu 18.04 STERO build 2020.10.05" > info  # Update version number to match your OS version
#echo "http//your-release-notes-url.com" > release_notes_url
#cd ../..

# Generate md5sum.txt
sudo /bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)"

# Create iso from the image directory using the command-line
sudo xorriso \
   -as mkisofs \
   -iso-level 3 \
   -full-iso9660-filenames \
   -volid "${DISK_NAME}" \
   -eltorito-boot boot/grub/bios.img \
   -no-emul-boot \
   -boot-load-size 4 \
   -boot-info-table \
   --eltorito-catalog boot/grub/boot.cat \
   --grub2-boot-info \
   --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
   -eltorito-alt-boot \
   -e EFI/efiboot.img \
   -no-emul-boot \
   -append_partition 2 0xef isolinux/efiboot.img \
   -output "../$OUTPUT_IMAGE_NAME" \
   -graft-points \
      "." \
      /boot/grub/bios.img=isolinux/bios.img \
      /EFI/efiboot.img=isolinux/efiboot.img

# Compress and split, if needed
cd "$ROOT_DIR"
#zip -s "${SPLIT_SIZE_MB}m" "$OUTPUT_IMAGE_NAME.zip" "$OUTPUT_IMAGE_NAME"
#7z "-v${SPLIT_SIZE_MB}m" a "$OUTPUT_IMAGE_NAME.7z" "$OUTPUT_IMAGE_NAME"
