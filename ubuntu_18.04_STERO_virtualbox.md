# How to create a bootable, live USB image of customized Ubuntu

Create a new virtual machine in VirtualBox, and name it stero_linux
Install Ubuntu 18.04 on the stero_linux virtual machine.

Run the system stero_linux on VirtualBox and install required software.

Upgrade the system:
```bash
sudo apt update
sudo apt Upgrade
```

Install VirtualBox guest additions - the instruction is at:
https://gist.github.com/estorgio/1d679f962e8209f8a9232f7593683265

Install some useful stuff:
```bash
sudo apt-get install -y \
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

Install Sublime:
```bash
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common

sudo -i
curl -fsSL https://download.sublimetext.com/sublimehq-pub.gpg | apt-key add -
```
Hit ctrl+d to exit root console.
```
sudo add-apt-repository "deb https://download.sublimetext.com/ apt/stable/"
sudo apt update
sudo apt install sublime-text
```

Install ROS:
```bash
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
sudo apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
sudo apt update
sudo apt install ros-melodic-desktop
```

Install dependencies for STERO workspaces:
```bash
git clone -b melodic-setup-working https://github.com/RCPRG-ros-pkg/RCPRG_rosinstall.git
cd RCPRG_rosinstall
scripts/check_deps.sh workspace_defs/main_dependencies
```
Remove RCPRG_rosinstall:
```bash
cd ..
rm -rf RCPRG_rosinstall
```

Now, almost all software is installed on this system.
Shutdown the system.

# Image of the filesystem

Now, you have to extract the filesystem.
For this purpose, you can use another virtual machine (let's name it helper_linux) with installed VirtualBox guest additions.
In VirtualBox, select the machine stero_linux and open Settings. Choose Memory panel and add a new
hard drive to IDE controllers. Select image of helper_linux. Start the virtual machine for stero_linux.
Mount the drive of stero_linux:
```bash
mkdir -p ~/mnt
sudo mount /dev/<device> ~/mnt
```
Mount shared folder as described in https://gist.github.com/estorgio/1d679f962e8209f8a9232f7593683265
```bash
mkdir -p ~/shared
sudo mount -t vboxsf shared ~/shared
```
Pack the filesystem of stero_linux:
```bash
cd ~/mnt
sudo tar -cf ~/shared/fs.tar *
```
Finally, unmount:
```bash
sudo umount ~/mnt
sudo umount ~/shared
```
Shutdown the virtual machine.

Extract the packed filesystem:
```bash
mkdir -p ~/live-ubuntu-from-scratch/chroot
cd ~/live-ubuntu-from-scratch/chroot
sudo tar -xf ~/VirtualBox\ VMs/stero_linux/shared/fs.tar
```

Install workspaces for STERO: copy all workspaces to /opt, e.g.:
```bash
sudo cp -r ~/ws_velma_install/opt/ws_* ~/live-ubuntu-from-scratch/chroot/opt
```

Adjust and run the script make_image.bash
