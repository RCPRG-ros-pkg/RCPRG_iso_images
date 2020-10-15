#!/usr/bin/env bash

# This script is based on:
# https://itnext.io/how-to-create-a-custom-ubuntu-live-from-scratch-dd3b3f213f81
# https://github.com/Tomas-M/linux-live.git

# Parameters - adjust for your needs
ROOT_DIR="$HOME/live-ubuntu-from-scratch"
BUILD_NAME=STERO
BUILD_DATE=20201012
BUILD_NUM=1

# The root directory of the destination filesystem relative to ROOT_DIR
FS_ROOT_SUBDIR=chroot

# Path to https://github.com/RCPRG-ros-pkg/linux-live.git:
LINUX_LIVE_PACKAGE_DIR="$HOME"/code/linux-live
KERNEL="5.4.0-48-generic"

REBUILD_INITRAMFS=1
REBUILD_SQUASHFS=1

if [ ! -d "$ROOT_DIR/image" ]; then
   REBUILD_INITRAMFS=1
   REBUILD_SQUASHFS=1
fi

# Useful variables
UNIQUE_NAME=`cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | head -n 1`
echo "Using unique name: $UNIQUE_NAME"

OUTPUT_IMAGE_NAME="ubuntu-18-04-${BUILD_DATE}${BUILD_NUM}.iso"
SPLIT_SIZE_MB=500
DISK_NAME="${BUILD_NAME}_${BUILD_DATE}_${BUILD_NUM}"

FILESYSTEM_FILENAME="fs"
FILESYSTEM_EXT="squ"

#LIVEKITNAME="${BUILD_NAME}${BUILD_DATE}${BUILD_NUM}"
# Write config for linux-live
cat <<EOF > "${LINUX_LIVE_PACKAGE_DIR}/config"
LIVEKITNAME=${UNIQUE_NAME}

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
BEXT=${FILESYSTEM_EXT}

# Directory with kernel .ko modules, can be different in some distros
LMK="lib/modules/\$KERNEL"
#LMK="$ROOT_DIR/$FS_ROOT_SUBDIR/lib/modules/\$KERNEL"

FS_ROOT="$ROOT_DIR/$FS_ROOT_SUBDIR"
EOF

. ${LINUX_LIVE_PACKAGE_DIR}/config

cd "$ROOT_DIR"

# Here we assume, the root filesystem is already created
# in folder $ROOT_DIR/chroot
if [ ! -d "$ROOT_DIR/$FS_ROOT_SUBDIR/etc" ]; then
   echo "ERROR: Could not find $ROOT_DIR/$FS_ROOT_SUBDIR/etc."
   echo "The root filesystem should be in $ROOT_DIR/$FS_ROOT_SUBDIR"
   exit 1
fi

if [ ! -f "$FS_ROOT_SUBDIR/boot/vmlinuz-$KERNEL" ]; then
   echo "ERROR: Could not find linux kernel at $FS_ROOT_SUBDIR/boot/vmlinuz-$KERNEL"
   exit 2
fi

# Add pre-login welcome message
#cat <<EOF > "$ROOT_DIR/issue"
#Ubuntu 18.04.5 LTS ${BUILD_NAME} Live build ${BUILD_DATE}${BUILD_NUM}
#Username is: ubuntu
#Password is empty
#To run graphical interface type:
#startx /usr/bin/xfce4-session
#EOF
#sudo mv "$ROOT_DIR/issue" "$ROOT_DIR/chroot/etc/issue"

# Create directories for destination filesystem
mkdir -p image/{casper,isolinux,install,boot}

# Copy some stuff
sudo cp $FS_ROOT_SUBDIR/boot/vmlinuz-$KERNEL image/casper/vmlinuz
USERNAME=$(whoami)
sudo chown $USERNAME:$USERNAME image/casper/vmlinuz

#sudo cp /boot/memtest86+.bin image/install/memtest86
# TODO: uncomment:
#wget --progress=dot https://www.memtest86.com/downloads/memtest86-usb.zip -O image/install/memtest86-usb.zip
#unzip -p image/install/memtest86-usb.zip memtest86-usb.img > image/install/memtest86
#rm image/install/memtest86-usb.zip

# Build initramfs image
if [[ ! -z ${REBUILD_INITRAMFS+x} ]]; then
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

# Write GRUB configuration
cat <<EOF > image/isolinux/grub.cfg

pager=1
regexp --set=root \(([^\(\)])+\) \$cmdpath
regexp --set=TEST_VAR \(([^\(\)])+\) \$cmdpath

insmod all_video

set default="0"
set timeout=30

menuentry "Run Ubuntu 18.04 ${BUILD_NAME} build ${BUILD_DATE}${BUILD_NUM} Live" {
   linux /casper/vmlinuz boot=casper quiet splash apparmor=0 ---
   initrd /casper/initrd
}

menuentry "Check disc for defects" {
   linux /casper/vmlinuz boot=casper integrity-check quiet splash apparmor=0 ---
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

# Create manifests
#sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee image/casper/filesystem.manifest
#sudo cp -v image/casper/filesystem.manifest image/casper/filesystem.manifest-desktop
#sudo sed -i '/ubiquity/d' image/casper/filesystem.manifest-desktop
#sudo sed -i '/casper/d' image/casper/filesystem.manifest-desktop
#sudo sed -i '/discover/d' image/casper/filesystem.manifest-desktop
#sudo sed -i '/laptop-detect/d' image/casper/filesystem.manifest-desktop
#sudo sed -i '/os-prober/d' image/casper/filesystem.manifest-desktop

#sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee "${FILESYSTEM_DIR}"/filesystem.manifest
#sudo cp -v "${FILESYSTEM_DIR}"/filesystem.manifest "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
#sudo sed -i '/ubiquity/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
#sudo sed -i '/casper/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
#sudo sed -i '/discover/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
#sudo sed -i '/laptop-detect/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
#sudo sed -i '/os-prober/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop

# Create squashfs
if [[ ! -z ${REBUILD_SQUASHFS+x} ]]; then
   echo "Rebuilding squashfs"

   # Check if the rights are as expected
   SUDO_LS=`ls -l "chroot/usr/bin/sudo"`
   if [ "${SUDO_LS:0:22}" != "-rwsr-xr-x 1 root root" ]; then
      echo "ERROR: wrong flags of chroot/usr/bin/sudo: should be -rwsr-xr-x"
      exit 1
   fi

   SQUASHFS_DEST_DIR=image/"${LIVEKITNAME}"

   rm -rf "$SQUASHFS_DEST_DIR"
   mkdir -p "$SQUASHFS_DEST_DIR"
   #sudo mksquashfs $FS_ROOT_SUBDIR image/casper/filesystem.squashfs
   sudo mksquashfs $FS_ROOT_SUBDIR "${SQUASHFS_DEST_DIR}/${FILESYSTEM_FILENAME}.${FILESYSTEM_EXT}"
fi

# Write filesystem size before compression
#printf $(sudo du -sx --block-size=1 chroot | cut -f1) > image/casper/filesystem.size

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

#
# Syslinux part for Boot in legacy mode
#
mkdir -p image/boot/syslinux
cp /usr/lib/ISOLINUX/isolinux.bin image/boot/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 image/isolinux/ # for syslinux 5.00 and newer


#cd "$ROOT_DIR/image"

BOOTFILES_DIR=$LINUX_LIVE_PACKAGE_DIR/bootfiles

cat <<EOF > image/boot/syslinux/syslinux.cfg
DEFAULT linux
LABEL linux
 SAY Now booting the kernel from SYSLINUX...
 KERNEL /casper/vmlinuz
 APPEND vga=769 initrd=/casper/initrd load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 apparmor=0
EOF

# BIOS / MBR booting
cp -r $BOOTFILES_DIR/* image/boot
#cat $BOOTFILES_DIR/syslinux.cfg | sed -r "s:/boot/:/$LIVEKITNAME/boot/:" > $BOOT/syslinux/syslinux.cfg
#cat $BOOTFILES_DIR/bootinst.bat | sed -r "s:/boot/:/$LIVEKITNAME/boot/:" | sed -r "s:\\\\boot\\\\:\\\\$LIVEKITNAME\\\\boot\\\\:" > $BOOT/bootinst.bat
#cp $BOOTFILES_DIR/syslinux.cfg $BOOT/syslinux/syslinux.cfg
cp $BOOTFILES_DIR/bootinst.bat image/boot/bootinst.bat
#cp casper/vmlinuz boot/ || exit

#
# end of Syslinux part
#


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

# Generate md5sum.txt
sudo /bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)"

sudo ${LINUX_LIVE_PACKAGE_DIR}/tools/isolinux.bin.update

sudo xorriso \
   -as mkisofs \
   -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
   -iso-level 3 \
   -full-iso9660-filenames \
   -volid "${DISK_NAME}" \
   -c boot/isolinux.boot \
   -b boot/isolinux.bin \
   -no-emul-boot \
   -boot-load-size 4 \
   -boot-info-table \
   -eltorito-alt-boot \
   -e EFI/efiboot.img \
   -no-emul-boot \
   -append_partition 2 0xef isolinux/efiboot.img \
   -output "../$OUTPUT_IMAGE_NAME" \
   -graft-points \
      "." \
      /EFI/efiboot.img=isolinux/efiboot.img

# Compress and split, if needed
cd "$ROOT_DIR"
#zip -s "${SPLIT_SIZE_MB}m" "$OUTPUT_IMAGE_NAME.zip" "$OUTPUT_IMAGE_NAME"
#7z "-v${SPLIT_SIZE_MB}m" a "$OUTPUT_IMAGE_NAME.7z" "$OUTPUT_IMAGE_NAME"

#sudo dd if=ubuntu-from-scratch.iso of=<device> status=progress
