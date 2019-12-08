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

killall apt apt-get
apt-get -y update && apt-get install -y -q nfs-kernel-server nmap pdsh screen git curl libnss3

mount -a

# Don't require password for HPC user sudo
echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Load modules, Install miniconda, intel-TF
echo `eval whoami` >> /home/$USER/whoami.log

export PATH=/opt/gcc-8.2.0/bin:$PATH
export LD_LIBRARY_PATH=/opt/gcc-8.2.0/lib64:$LD_LIBRARY_PATH
export CC=/opt/gcc-8.2.0/bin/gcc
export GCC=/opt/gcc-8.2.0/bin/gcc

export PATH=/opt/intel/compilers_and_libraries/linux/mpi/intel64/bin:$PATH
export LD_LIBRARY_PATH=/opt/intel/compilers_and_libraries/linux/mpi/intel64/lib:$LD_LIBRARY_PATH


INSTALL_PREFIX=/opt

wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p ${INSTALL_PREFIX}/miniconda3
rm -rf Miniconda3-latest-Linux-x86_64.sh
chown -R $USER:$USER /${INSTALL_PREFIX}/miniconda3/

conda_path="export PATH=${INSTALL_PREFIX}/miniconda3/bin:$PATH"
export PATH=${INSTALL_PREFIX}/miniconda3/bin:$PATH

conda create -y --name intel-tf-py36 -c intel python=3 pip 
#${INSTALL_PREFIX}/miniconda3/envs/intel-tf-py36/bin/pip install --no-cache-dir intel-tensorflow horovod

su - $USER -c "${INSTALL_PREFIX}/miniconda3/bin/conda init bash"
echo "module load gcc-8.2.0" >> /home/$USER/.bashrc    
echo "module load mpi/impi_2018.4.274" >> /home/$USER/.bashrc  

