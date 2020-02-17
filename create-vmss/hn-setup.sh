#!/bin/bash

scriptUri=$1
USER=$2

githubUser=$(echo "$scriptUri" | cut -d'/' -f4)
githubRepo=$(echo "$scriptUri" | cut -d'/' -f5)
githubBranch=$(echo "$scriptUri" | cut -d'/' -f6)

IP=`ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
localip=`echo $IP | cut --delimiter='.' -f -3`

mkdir -p /mnt/resource
chmod a+rwx /mnt/resource

#killall apt apt-get
#apt-get -y update && apt-get install -y -q nfs-kernel-server nmap pdsh screen git curl libnss3

# Host NFS
cat << EOF >> /etc/exports
/home $localip.*(rw,sync,no_root_squash,no_all_squash)
/mnt/resource $localip.*(rw,sync,no_root_squash,no_all_squash)
EOF

mkdir -p /mnt/resource/slurm

systemctl enable rpcbind
systemctl enable nfs-server
systemctl start rpcbind
systemctl start nfs-server
systemctl restart nfs-server
systemctl restart munge

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

touch /mnt/resource/slurm/cluster.conf
# Daemon reload and restart slurmctld
# systemctl daemon-reload
#systemctl restart slurmdbd
systemctl restart slurmctld
