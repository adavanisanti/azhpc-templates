#!/bin/bash

# fail on any error
set -e

HEADNODE=$1
USER=$2

# Add script for generating hostfile

sed -i 's/^ResourceDisk.MountPoint=\/mnt\/resource$/ResourceDisk.MountPoint=\/mnt\/local_resource/g' /etc/waagent.conf
#umount /mnt/resource

mkdir -p /mnt/resource/


mount $HEADNODE:/home /home
mount $HEADNODE:/mnt/resource /mnt/resource

mount -a
# Don't require password for HPC user sudo
echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo "NodeName=`hostname -s`" >> /etc/slurm/gres.conf
echo `python /home/$USER/azhpc-templates/create-vmss/scripts/generate_node_conf.py` >> /mnt/resource/slurm/cluster.conf
cp /mnt/resource/slurm/slurm.conf /etc/slurm/

# Restart munge slurmd
# systemctl daemon-reload
systemctl restart slurmd
