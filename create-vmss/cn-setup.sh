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

INSTALL_PREFIX=/opt
GCC_VER=9.2.0
IMPI_VER=2019
CONDA_ENV_NAME=intel-tf-py36
TF_VER=1.13.2
HVD_VER=0.18.2

export PATH=/opt/gcc-${GCC_VER}/bin:$PATH
export LD_LIBRARY_PATH=/opt/gcc-${GCC_VER}/lib64:$LD_LIBRARY_PATH
export CC=/opt/gcc-${GCC_VER}/bin/gcc
export GCC=/opt/gcc-${GCC_VER}/bin/gcc

export PATH=/opt/intel/compilers_and_libraries/linux/mpi/intel64/bin:$PATH
export LD_LIBRARY_PATH=/opt/intel/compilers_and_libraries/linux/mpi/intel64/lib:$LD_LIBRARY_PATH

# Install miniconda3

wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p ${INSTALL_PREFIX}/miniconda3
rm -rf Miniconda3-latest-Linux-x86_64.sh
chown -R $USER:$USER /${INSTALL_PREFIX}/miniconda3/

conda_path="export PATH=${INSTALL_PREFIX}/miniconda3/bin:$PATH"
export PATH=${INSTALL_PREFIX}/miniconda3/bin:$PATH

# Create TF conda environment

conda create -y --name $CONDA_ENV_NAME -c intel pip python=3.6
${INSTALL_PREFIX}/miniconda3/envs/${CONDA_ENV_NAME}/bin/pip install --no-cache-dir intel-tensorflow==${TF_VER} horovod==${HVD_VER} gdown

# Setup environment when user logs in by setting .bashrc profile
su - $USER -c "${INSTALL_PREFIX}/miniconda3/bin/conda init bash"
echo "module load gcc-${GCC_VER}" >> /home/$USER/.bashrc
echo "module load mpi/impi-${IMPI_VER}" >> /home/$USER/.bashrc
echo "source /opt/intel/compilers_and_libraries/linux/mpi/intel64/bin/mpivars.sh" >> /home/$USER/.bashrc
echo "conda activate $CONDA_ENV_NAME " >> /home/$USER/.bashrc

# GIT clone TF benchmarks repo
git clone -b cnn_tf_v1.13_compatible  https://github.com/tensorflow/benchmarks.git /home/$USER/benchmarks
chown -R $USER:$USER /home/$USER/benchmarks

