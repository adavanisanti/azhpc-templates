#!/bin/bash

# fail on any error
set -e

HEADNODE=$1
USER=$2

sed -i 's/^ResourceDisk.MountPoint=\/mnt\/resource$/ResourceDisk.MountPoint=\/mnt\/local_resource/g' /etc/waagent.conf
#umount /mnt/resource

mkdir -p /mnt/resource/scratch

cat << EOF >> /etc/fstab
$HEADNODE:/home    /home   nfs defaults 0 0
$HEADNODE:/mnt/resource/scratch    /mnt/resource/scratch   nfs defaults 0 0
EOF

#apt-get -y update && apt-get install -y -q nfs-kernel-server nmap pdsh screen git curl libnss3

mount -a

# Don't require password for HPC user sudo
echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Load modules, Install miniconda, intel-TF
echo `eval whoami` >> /home/$USER/whoami.log

