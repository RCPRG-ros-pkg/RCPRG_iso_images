# How to create a bootable, live USB image of customized Ubuntu

Based on:
https://itnext.io/how-to-create-a-custom-ubuntu-live-from-scratch-dd3b3f213f81

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

After this stage cleanup is not required.

# STAGE 2

Mount dev and run:
```bash
sudo mount --bind /dev $HOME/live-ubuntu-from-scratch/chroot/dev
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

## Cleanup after stage 2
After this stage cleanup is:
```bash
umount -l /proc
umount -l /sys
umount -l /dev/pts
export HISTSIZE=0
exit
```
and then:
```bash
sudo umount -l $HOME/live-ubuntu-from-scratch/chroot/dev
sudo umount -l  $HOME/live-ubuntu-from-scratch/chroot/run
```

## Resuming after stage 2

To resume after stage 2 is created:
```bash
sudo mount --bind /dev $HOME/live-ubuntu-from-scratch/chroot/dev
sudo mount --bind /run $HOME/live-ubuntu-from-scratch/chroot/run
sudo chroot $HOME/live-ubuntu-from-scratch/chroot
```
and then:
```bash
mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C
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
Create user:
```bash
useradd -s /bin/bash -d /home/student -m -G sudo student
passwd student
```

## Cleanup after stage 3
After this stage cleanup is the same as after stage 2.

## Resuming after stage 3

To resume after stage 2 is created:
```bash
sudo mount --bind /dev $HOME/live-ubuntu-from-scratch/chroot/dev
sudo mount --bind /run $HOME/live-ubuntu-from-scratch/chroot/run
sudo chroot $HOME/live-ubuntu-from-scratch/chroot
```
and then:
```bash
mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C
```
and finally:
```bash
ln -fs /etc/machine-id /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl
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
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update
apt-get install google-chrome-stable
```

Install Sublime:
```bash
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
sudo add-apt-repository "deb https://download.sublimetext.com/ apt/stable/"
sudo apt update
sudo apt install sublime-text
```

## Cleanup after stage 4
After this stage cleanup is the same as after stage 3.

## Resuming after stage 4
Resuming after stage 4 is the same as after stage 3.

# STAGE 5: ROS

Install ROS:
```bash
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
sudo apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
sudo apt update
sudo apt install ros-melodic-desktop
```

## Cleanup after stage 5
After this stage cleanup is the same as after stage 3.

## Resuming after stage 5
Resuming after stage 4 is the same as after stage 3.

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

## Cleanup after stage 7
After this stage cleanup is the same as after stage 3.

## Resuming after stage 7
Resuming after stage 4 is the same as after stage 3.

# STAGE 8: final cleanup

```bash
apt-get autoremove -y
dpkg-reconfigure locales
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
