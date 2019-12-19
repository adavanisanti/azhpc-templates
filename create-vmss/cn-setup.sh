#!/bin/bash

# fail on any error
set -e

HEADNODE=$1
USER=$2

# Add script for generating hostfile

sed -i 's/^ResourceDisk.MountPoint=\/mnt\/resource$/ResourceDisk.MountPoint=\/mnt\/local_resource/g' /etc/waagent.conf
#umount /mnt/resource

mkdir -p /mnt/resource/

cat << EOF >> /etc/fstab
$HEADNODE:/home    /home   nfs defaults 0 0
$HEADNODE:/mnt/resource/    /mnt/resource/   nfs defaults 0 0
EOF

#apt-get -y update && apt-get install -y -q nfs-kernel-server nmap pdsh screen git curl libnss3

mount -a
# Don't require password for HPC user sudo
echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Start slurmd
# systemctl restart slurmd

# Load modules, Install miniconda, intel-TF
echo `eval whoami` >> /home/$USER/whoami.log


echo "NodeName=`hostname -s`" >> /etc/slurm/gres.conf
echo `python /home/$USER/azhpc-templates/create-vmss/scripts/generate_node_conf.py` >> /mnt/resource/slurm/cluster.conf
cp /mnt/resource/slurm/slurm.conf /etc/slurm/

# Restart munge slurmd
#systemctl daemon-reload
#systemctl restart munge
#systemctl restart slurmd

