#!/bin/bash

scriptUri=$1
githubUser=$(echo "$scriptUri" | cut -d'/' -f4)
githubRepo=$(echo "$scriptUri" | cut -d'/' -f5)
githubBranch=$(echo "$scriptUri" | cut -d'/' -f6)

IP=`ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
localip=`echo $IP | cut --delimiter='.' -f -3`

mkdir -p /mnt/resource/scratch
chmod a+rwx /mnt/resource/scratch

yum --enablerepo=extras install -y -q epel-release
yum install -y -q nfs-utils nmap pdsh screen git
# need to update for git work
yum update -y nss curl libcurl

# Host NFS
cat << EOF >> /etc/exports
/home $localip.*(rw,sync,no_root_squash,no_all_squash)
/mnt/resource/scratch $localip.*(rw,sync,no_root_squash,no_all_squash)
EOF

systemctl enable rpcbind
systemctl enable nfs-server
systemctl enable nfs-lock
systemctl enable nfs-idmap
systemctl start rpcbind
systemctl start nfs-server
systemctl start nfs-lock
systemctl start nfs-idmap
systemctl restart nfs-server

USER=$2
GCC_MODULE_NAME=$(basename `find /usr/share/Modules/modulefiles/ -iname gcc-*`)

OMPI_VERSION=4.0.2

# Setup environment when user logs in by setting .bashrc profile
cat << EOF >> /home/$USER/.bashrc
export WCOLL=/home/$USER/hostfile
module load ${GCC_MODULE_NAME}
module load mpi/openmpi
EOF

# Load corresponding MPI library (based on branch name)
MPI_MODULE_NAME=$(basename `find /usr/share/Modules/modulefiles/mpi/ -iname ${githubBranch}-*`)

# Setup environment when user logs in by setting .bashrc profile
if [[ $MPI_MODULE_NAME ]]; then
    cat << EOF >> /home/$USER/.bashrc
module load mpi/${MPI_MODULE_NAME}
EOF
fi

chown $USER:$USER /home/$USER/.bashrc
touch /home/$USER/hostfile
chown $USER:$USER /home/$USER/hostfile

# Setup passwordless ssh to compute nodes
ssh-keygen -f /home/$USER/.ssh/id_rsa -t rsa -N ''
cat << EOF > /home/$USER/.ssh/config
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    PasswordAuthentication no
    LogLevel QUIET
EOF
cat /home/$USER/.ssh/id_rsa.pub >> /home/$USER/.ssh/authorized_keys
chmod 644 /home/$USER/.ssh/config
chown $USER:$USER /home/$USER/.ssh/*

# Don't require password for HPC user sudo
echo "$USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Add script for generating hostfile
cd /tmp
git clone -b $githubBranch https://github.com/$githubUser/$githubRepo.git
cd azhpc-templates/create-vmss/scripts/
mkdir -p /home/$USER/scripts
cp -r * /home/$USER/scripts/
chmod +x /home/$USER/scripts/*
chown -R $USER:$USER /home/$USER/scripts
cd / && rm -rf /tmp/*


# Setup and Install TF-CNN-Benchmarks. (1) Env setup (2) Install miniconda, intel-TF
# Installations done on headnode, as /home folder is synced with all compute nodes.

INSTALL_PREFIX=/home/$USER/
GCC_VER=9.2.0

CONDA_ENV_NAME=intel-tf-py36
TF_VER=1.13.2
HVD_VER=0.18.0

export PATH=/opt/gcc-${GCC_VER}/bin:$PATH
export LD_LIBRARY_PATH=/opt/gcc-${GCC_VER}/lib64:$LD_LIBRARY_PATH
export CC=/opt/gcc-${GCC_VER}/bin/gcc
export GCC=/opt/gcc-${GCC_VER}/bin/gcc

export PATH=/opt/openmpi-${OMPI_VERSION}/bin:$PATH
export LD_LIBRARY_PATH=/opt/openmpi-${OMPI_VERSION}/lib:$LD_LIBRARY_PATH

# Install miniconda3

wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p ${INSTALL_PREFIX}/miniconda3
rm -rf Miniconda3-latest-Linux-x86_64.sh

conda_path="export PATH=${INSTALL_PREFIX}/miniconda3/bin:$PATH"
export PATH=${INSTALL_PREFIX}/miniconda3/bin:$PATH

# Create TF conda environment
conda create -y --name $CONDA_ENV_NAME -c intel pip python=3.6
${INSTALL_PREFIX}/miniconda3/envs/${CONDA_ENV_NAME}/bin/pip install --no-cache-dir intel-tensorflow==${TF_VER} horovod==${HVD_VER} gdown

# give the user full permission of conda env
chown -R $USER:$USER /${INSTALL_PREFIX}/miniconda3/

# Setup miniconda environment in .bashrc profile
su - $USER -c "${INSTALL_PREFIX}/miniconda3/bin/conda init bash"
echo "conda activate $CONDA_ENV_NAME" >> /home/$USER/.bashrc

# GIT clone TF benchmarks repo
git clone -b cnn_tf_v1.13_compatible  https://github.com/tensorflow/benchmarks.git /home/$USER/benchmarks
chown -R $USER:$USER /home/$USER/benchmarks
