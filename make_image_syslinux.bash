#!/usr/bin/env bash

# This script requires:
# https://github.com/Tomas-M/linux-live.git

# Parameters - adjust for your needs
ROOT_DIR="$HOME"/live-ubuntu-from-scratch
BUILD_NAME=STERO
BUILD_DATE=20201007
BUILD_NUM=4
# Path to https://github.com/Tomas-M/linux-live.git:
LINUX_LIVE_PACKAGE_DIR="$HOME"/code/linux-live
KERNEL="4.15.0-118-generic"

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

echo "LIVEKITNAME: $LIVEKITNAME"

# Useful variables
OUTPUT_IMAGE_NAME="ubuntu-18-04-${BUILD_DATE}${BUILD_NUM}.img"
SPLIT_SIZE_MB=500
DISK_NAME="Ubuntu 18.04-${BUILD_NAME}-${BUILD_DATE}_${BUILD_NUM}"

# Here we assume, the root filesystem is already created
# in folder $ROOT_DIR/chroot
if [ ! -d "$ROOT_DIR/chroot/etc" ]; then
   echo "ERROR: Could not find $ROOT_DIR/chroot/etc."
   echo "The root filesystem should be in $ROOT_DIR/chroot"
   exit 1
fi

# Add pre-login welcome message (/etc/issue)
cat <<EOF > "$ROOT_DIR/issue"
Ubuntu 18.04.5 LTS ${BUILD_NAME} Live build ${BUILD_DATE}${BUILD_NUM}

Username is: student
Password is: student

To run graphical interface type:
startx /usr/bin/xfce4-session

EOF
sudo mv "$ROOT_DIR/issue" "$ROOT_DIR/chroot/etc/issue"

# Create directories for destination filesystem
cd "$ROOT_DIR"
mkdir -p image/{isolinux,boot}

# Copy some stuff
sudo cp chroot/boot/vmlinuz-**-**-generic image/boot/vmlinuz
USERNAME=$(whoami)
sudo chown $USERNAME:$USERNAME image/boot/vmlinuz

mkdir -p image/boot/syslinux
mkdir -p image/"${LIVEKITNAME}"
cp /usr/lib/ISOLINUX/isolinux.bin image/boot/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 image/isolinux/ # for syslinux 5.00 and newer

# Create base point access file for grub
# Set some unique name, so that GRUB can find this USB stick among multiple other drives.
# Later, we search for this file from our GRUB.

FILESYSTEM_DIR=image/"${LIVEKITNAME}"

# Create manifests
sudo chroot chroot dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee "${FILESYSTEM_DIR}"/filesystem.manifest
sudo cp -v "${FILESYSTEM_DIR}"/filesystem.manifest "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
sudo sed -i '/ubiquity/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
sudo sed -i '/discover/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
sudo sed -i '/laptop-detect/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop
sudo sed -i '/os-prober/d' "${FILESYSTEM_DIR}"/filesystem.manifest-desktop

# Create squashfs
sudo mksquashfs chroot "${FILESYSTEM_DIR}"/filesystem.squashfs

# Write filesystem size before compression
printf $(sudo du -sx --block-size=1 chroot | cut -f1) > "${FILESYSTEM_DIR}"/filesystem.size

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

BOOTFILES_DIR=$LINUX_LIVE_PACKAGE_DIR/bootfiles

cat <<EOF > boot/syslinux/syslinux.cfg
DEFAULT linux
LABEL linux
 SAY Now booting the kernel from SYSLINUX...
 KERNEL /boot/vmlinuz
 APPEND vga=769 initrd=/boot/initrfs.img load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0 apparmor=0
EOF

# BIOS / MBR booting
cp -r $BOOTFILES_DIR/* boot
#cat $BOOTFILES_DIR/syslinux.cfg | sed -r "s:/boot/:/$LIVEKITNAME/boot/:" > $BOOT/syslinux/syslinux.cfg
#cat $BOOTFILES_DIR/bootinst.bat | sed -r "s:/boot/:/$LIVEKITNAME/boot/:" | sed -r "s:\\\\boot\\\\:\\\\$LIVEKITNAME\\\\boot\\\\:" > $BOOT/bootinst.bat
#cp $BOOTFILES_DIR/syslinux.cfg $BOOT/syslinux/syslinux.cfg
cp $BOOTFILES_DIR/bootinst.bat boot/bootinst.bat
#cp casper/vmlinuz boot/ || exit

# UEFI booting
mkdir -p boot/EFI/Boot
cp $BOOTFILES_DIR/EFI/Boot/syslinux.efi boot/EFI/Boot/bootx64.efi
cp $BOOTFILES_DIR/EFI/Boot/{ldlinux.e64,menu.c32,libutil.c32,vesamenu.c32,libcom32.c32} boot/EFI/Boot
#cat boot/syslinux.cfg | sed -r "s:/$LIVEKITNAME/boot/vesamenu:vesamenu:" > boot/EFI/Boot/syslinux.cfg
cp boot/syslinux/syslinux.cfg boot/EFI/Boot/syslinux.cfg

# Build initramfs image
echo "Building intramfs image..."
cd $LINUX_LIVE_PACKAGE_DIR/initramfs
INITRAMFS=$(./initramfs_create)
cd "$ROOT_DIR/image"

if [ "$INITRAMFS" != "" ]; then
   mv "$INITRAMFS" boot/initrfs.img
fi

# Generate md5sum.txt
sudo /bin/bash -c "(find . -type f -print0 | xargs -0 md5sum | grep -v "\./md5sum.txt" > md5sum.txt)"

# This command creates a valid, bootable image for CD and it cannot be used in USB (no MBR):
#mkisofs -o "../$OUTPUT_IMAGE_NAME" -v -J -R -D -A "$LIVEKITNAME" -V "$LIVEKITNAME" \
#-no-emul-boot -boot-info-table -boot-load-size 4 \
#-b boot/isolinux.bin -c boot/isolinux.boot .

# This created image with MBR:
xorriso -as mkisofs \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -volid "${DISK_NAME}" \
  -c boot/isolinux.boot \
  -b boot/isolinux.bin \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e boot/EFI/Boot/bootx64.efi \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  -o "../$OUTPUT_IMAGE_NAME" \
  .

# Compress and split, if needed
cd "$ROOT_DIR"
#zip -s "${SPLIT_SIZE_MB}m" "$OUTPUT_IMAGE_NAME.zip" "$OUTPUT_IMAGE_NAME"
#7z "-v${SPLIT_SIZE_MB}m" a "$OUTPUT_IMAGE_NAME.7z" "$OUTPUT_IMAGE_NAME"
