# How to create a bootable, live USB image of customized Ubuntu

Based on:
https://itnext.io/how-to-create-a-custom-ubuntu-live-from-scratch-dd3b3f213f81

# STAGE 1

mkdir $HOME/live-ubuntu-from-scratch

sudo debootstrap \
    --arch=amd64 \
    --variant=minbase \
    bionic \
    $HOME/live-ubuntu-from-scratch/chroot \
    http://us.archive.ubuntu.com/ubuntu/

# STAGE 2

sudo mount --bind /dev $HOME/live-ubuntu-from-scratch/chroot/dev
sudo mount --bind /run $HOME/live-ubuntu-from-scratch/chroot/run

sudo chroot $HOME/live-ubuntu-from-scratch/chroot

mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C

echo "ubuntu-fs-live" > /etc/hostname

cat <<EOF > /etc/apt/sources.list
deb http://us.archive.ubuntu.com/ubuntu/ bionic main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ bionic main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ bionic-security main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ bionic-security main restricted universe multiverse
deb http://us.archive.ubuntu.com/ubuntu/ bionic-updates main restricted universe multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ bionic-updates main restricted universe multiverse    
EOF

apt-get update

apt-get install -y systemd-sysv

# STAGE 3

dbus-uuidgen > /etc/machine-id
ln -fs /etc/machine-id /var/lib/dbus/machine-id


dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

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

# STAGE 4

apt-get install \
    plymouth-theme-ubuntu-logo \
    xfce4

apt-get install -y \
    clamav-daemon \
    terminator \
    apt-transport-https \
    curl \
    vim \
    nano \
    less \
    git \
    mc

# STAGE 5

sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'

sudo apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
sudo apt update
sudo apt install ros-melodic-desktop

wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
echo "deb http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
apt-get update
apt-get install google-chrome-stable

sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
sudo add-apt-repository "deb https://download.sublimetext.com/ apt/stable/"
sudo apt update
sudo apt install sublime-text

# STAGE 6

git clone -b melodic-setup-working https://github.com/RCPRG-ros-pkg/RCPRG_rosinstall.git
cd RCPRG_rosinstall
scripts/check_deps.sh workspace_defs/main_dependencies
cd ..
rm -rf RCPRG_rosinstall

# STAGE 7

# copy all workspaces to /opt

cat <<EOF > /etc/issue
Ubuntu 18.04.5 LTS STERO Live build \n \l

EOF

apt-get autoremove -y

dpkg-reconfigure locales

dpkg-reconfigure resolvconf

cat <<EOF > /etc/NetworkManager/NetworkManager.conf
[main]
rc-manager=resolvconf
plugins=ifupdown,keyfile
dns=dnsmasq
[ifupdown]
managed=false
EOF


dpkg-reconfigure network-manager


truncate -s 0 /etc/machine-id

rm /sbin/initctl
dpkg-divert --rename --remove /sbin/initctl

apt-get clean
rm -rf /tmp/* ~/.bash_history
umount /proc
umount /sys
umount /dev/pts
export HISTSIZE=0
exit


sudo umount $HOME/live-ubuntu-from-scratch/chroot/dev
sudo umount $HOME/live-ubuntu-from-scratch/chroot/run


# RESUME FROM STAGE 2

sudo mount --bind /dev $HOME/live-ubuntu-from-scratch/chroot/dev
sudo mount --bind /run $HOME/live-ubuntu-from-scratch/chroot/run

sudo chroot $HOME/live-ubuntu-from-scratch/chroot

mount none -t proc /proc
mount none -t sysfs /sys
mount none -t devpts /dev/pts
export HOME=/root
export LC_ALL=C

# Continue with stage 3
# RESUME FROM STAGE 3

# resume from stage 2

ln -fs /etc/machine-id /var/lib/dbus/machine-id
dpkg-divert --local --rename --add /sbin/initctl
ln -s /bin/true /sbin/initctl

# Continue with stage 4

# RESUME FROM STAGE 4

# resume from stage 3


