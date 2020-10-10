# How to create a bootable, live USB image of customized Ubuntu

Based on:
https://itnext.io/how-to-create-a-custom-ubuntu-live-from-scratch-dd3b3f213f81

# Required packages

Install packages:
```bash
sudo apt-get install \
    binutils \
    debootstrap \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools
```

# STAGE 1

Create a new root filesystem and populate it with minimum required files and folders:
```bash
mkdir $HOME/live-ubuntu-from-scratch

sudo debootstrap \
    --arch=amd64 \
    --variant=minbase \
    bionic \
    $HOME/live-ubuntu-from-scratch/chroot \
    http://us.archive.ubuntu.com/ubuntu/
```

# STAGE 2

Mount dev:
```bash
sudo mount --bind /dev $HOME/live-ubuntu-from-scratch/chroot/dev
```
Mount run:
```bash
sudo mount --bind /run $HOME/live-ubuntu-from-scratch/chroot/run
```

Swith to the new root filesystem:
```bash
sudo chroot $HOME/live-ubuntu-from-scratch/chroot
```

Mount some folders, set locale and set hostname:
```bash
mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C
echo "ubuntu-fs-live" > /etc/hostname
```

Set sources list:
```bash
cat <<EOF > /etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu/ bionic main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ bionic main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ bionic-security main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ bionic-security main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ bionic-updates main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ bionic-updates main restricted universe multiverse    
EOF
```

Update packages:
```bash
apt-get update
```

Install systemd:
```bash
apt-get install -y systemd-sysv
```

# STAGE 3

Set machine uuid:
```bash
dbus-uuidgen > /etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id
```
Set diversion:
```bash
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl
```
Add line to etc/resolvconf/resolv.conf.d/tail
```bash
nameserver 127.0.1.1
```
Install required packages: 
```bash
apt-get install -y \
    ubuntu-standard \
    casper \
    lupin-casper \
    discover \
    laptop-detect \
    os-prober \
    network-manager \
    resolvconf \
    net-tools \
    wireless-tools \
    wpagui \
    locales \
    linux-generic
```
Configure grub: Don’t select any options, Only confirm "Yes".

Create user:
```bash
useradd -s /bin/bash -d /home/student -m -G sudo student
passwd student
```


# STAGE 4: xfce, optional packages

Install graphical interface:
```bash
apt-get install \
    plymouth-theme-ubuntu-logo \
    xfce4
```

Install some optional stuff:
```bash
apt-get install -y \
    clamav-daemon \
    terminator \
    apt-transport-https \
    curl \
    vim \
    nano \
    less \
    git \
    mc \
    htop
```

Install Google Crome:
```bash
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update
apt-get install google-chrome-stable
```

Install Sublime:
```bash
apt update
apt install apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -
add-apt-repository "deb https://download.sublimetext.com/ apt/stable/"
apt update
apt install sublime-text
```


# STAGE 5: ROS

Install ROS:
```bash
sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
apt update
apt install ros-melodic-desktop
```

# STAGE 6: dependencies for STERO workspaces

Install dependencies for STERO workspaces:
```bash
git clone -b melodic-setup-working https://github.com/RCPRG-ros-pkg/RCPRG_rosinstall.git
cd RCPRG_rosinstall
scripts/check_deps.sh workspace_defs/main_dependencies
cd ..
rm -rf RCPRG_rosinstall
```

## Cleanup after stage 6
After this stage cleanup is the same as after stage 3.

## Resuming after stage 6
Resuming after stage 4 is the same as after stage 3.

# STAGE 7: STERO workspaces

Install workspaces for STERO: copy all workspaces to /opt

# STAGE 8: final cleanup

```bash
apt-get autoremove -y
dpkg-reconfigure locales
```
Reconfigure resolvconf
```bash
dpkg-reconfigure resolvconf
```

```bash
cat <<EOF > /etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=dnsmasq
[ifupdown]
managed=false
EOF
```

```bash
dpkg-reconfigure network-manager
truncate -s 0 /etc/machine-id
rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl
```

```bash
apt-get clean
rm -rf /tmp/* ~/.bash_history
umount /proc
umount /sys
umount /dev/pts
export HISTSIZE=0
exit
```

```bash
sudo umount $HOME/live-ubuntu-from-scratch/chroot/dev
sudo umount $HOME/live-ubuntu-from-scratch/chroot/run
```

# Troubleshooting

## Network in chroot does not work

Copy resolv.conf from the host:
```bash
sudo rm ~/live-ubuntu-from-scratch/chroot/etc/resolv.conf 
sudo cp /etc/resolv.conf ~/live-ubuntu-from-scratch/chroot/etc/
```
Then, after you finish your work, you have to cleanup resolv.conf:
```bash
cd /etc
ln -s -T ../run/systemd/resolve/stub-resolv.conf resolv.conf
```
