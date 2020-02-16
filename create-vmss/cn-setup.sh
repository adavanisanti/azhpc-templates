#!/bin/bash

# fail on any error
set -e

HEADNODE=$1
USER=$2
scriptUri=$3

githubUser=$(echo "$scriptUri" | cut -d'/' -f4)
githubRepo=$(echo "$scriptUri" | cut -d'/' -f5)
githubBranch=$(echo "$scriptUri" | cut -d'/' -f6)
# Add script for generating hostfile

sed -i 's/^ResourceDisk.MountPoint=\/mnt\/resource$/ResourceDisk.MountPoint=\/mnt\/local_resource/g' /etc/waagent.conf
#umount /mnt/resource

mkdir -p /mnt/resource/

cat << EOF >> /etc/exports
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

cd /home/$USER
git clone -b $githubBranch https://github.com/$githubUser/$githubRepo.git
cd azhpc-templates/create-vmss/scripts/
chmod +x slurm.conf.sh

# Add slurmctld restart in rc.local only on master node
cp rc.local /etc/
chmod +x /etc/rc.local

chown $USER:$USER /home/$USER/azhpc-templates/create-vmss/scripts/

bash slurm.conf.sh >> /mnt/resource/slurm/slurm.conf
cp /mnt/resource/slurm/slurm.conf /etc/slurm/

echo "NodeName=`hostname -s`" >> /etc/slurm/gres.conf
echo `python /home/$USER/azhpc-templates/create-vmss/scripts/generate_node_conf.py` >> /mnt/resource/slurm/cluster.conf

# Restart munge slurmd
# systemctl daemon-reload
systemctl restart slurmd

