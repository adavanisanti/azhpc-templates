#!/bin/bash

# fail on any error
set -e

HEADNODE=$1
USER=$2

sed -i 's/^ResourceDisk.MountPoint=\/mnt\/resource$/ResourceDisk.MountPoint=\/mnt\/local_resource/g' /etc/waagent.conf
umount /mnt/resource

mkdir -p /mnt/resource/scratch

cat << EOF >> /etc/fstab
$HEADNODE:/home    /home   nfs defaults 0 0
$HEADNODE:/mnt/resource/scratch    /mnt/resource/scratch   nfs defaults 0 0
EOF

until yum install -y -q nfs-utils
do
    sleep 10
done
setsebool -P use_nfs_home_dirs 1

mount -a

# Don't require password for HPC user sudo
echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Load modules, Install miniconda, intel-TF
echo `eval whoami` >> /home/$USER/whoami.log

module load gcc-8.2.0
module load mpi/impi_2018.4.274

INSTALL_PREFIX=/opt

wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p ${INSTALL_PREFIX}/miniconda3
rm -rf Miniconda3-latest-Linux-x86_64.sh

conda_path="export PATH=${INSTALL_PREFIX}/miniconda3/bin:$PATH"
export PATH=${INSTALL_PREFIX}/miniconda3/bin:$PATH

conda create -y --name intel-tf-py36 -c intel python=3 pip 
${INSTALL_PREFIX}/miniconda3/envs/intel-tf-py36/bin/pip install --no-cache-dir intel-tensorflow horovod

su - $USER -c "${INSTALL_PREFIX}/miniconda3/bin/conda init bash"
echo "module load gcc-8.2.0" >> /home/$USER/.bashrc    
echo "module load mpi/impi_2018.4.274" >> /home/$USER/.bashrc  
