
# Tensorflow benchmarking by creating Virtual Machine Scale Set using SR-IOV enabled Azure HPC VMs

This will deploy a [Virtual Machine Scale Set (VMSS)](#https://docs.microsoft.com/azure/virtual-machine-scale-sets/overview) using the SR-IOV enabled Azure VM types.

The deployed VM's will have environment ready with
- Intel-Tensorflow v1.13.2
- Horovod v0.18.0
- Open MPI 4.0.2. See [instructions here](#using-hpc-x-mpi-library) to use HPC-X.
- Conda environment named: intel-tf-py36
- [Tensorflow CNN Benchmarks compatible with TF v1.13](https://github.com/tensorflow/benchmarks/tree/cnn_tf_v1.13_compatible/scripts/tf_cnn_benchmarks)
- [Distributed Training Benchmark script](scripts/tf-bench-ompi.sh) Refer to [instructions here](#step-3-launch-benchmarks) to launch benchmarks.


Click on the following **Deploy to Azure** link to start your deployment.

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fravi9%2Fazhpc-templates%2Ftf-bench-ompi%2Fcreate-vmss%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png" />
</a>

#### **NOTE**: Setting up environment will take few minutes. Please login after about 10min. The head-node will be available for login, but installation will take some time. To check the installation status, see
``` sudo cat /var/lib/waagent/custom-script/download/0/stdout ```

## Input Fields

The above link opens up a template form with the following input fields:

- **Azure Subscription** - Subscription for VMSS deployment.
- **Resource Group** - Resource group under for VMSS. New resource group can be created using the "Create New" link.
- **Location** - VMSS Location.
- **VM SKU** - VM SKU type (Only SR-IOV enabled SKU types are included in the list).
- **Compute Node Image** - OS image for VMSS. Select the "-HPC" flavor for an [optimized HPC image](https://techcommunity.microsoft.com/t5/Azure-Compute/CentOS-HPC-VM-Image-for-SR-IOV-enabled-Azure-HPC-VMs/ba-p/665557).
- **Instance Count** - Number of VMs in the scale set.
- **Username** - Username for VMs.
- **Password** - Password for VMs.
- **RSA Public Key** - RSA Public Key for "ssh"-ing into the head node.

## Cluster Architecture

With this deployment, a head node and a VMSS are created.

### Head Node

The head node can be identified as "`<vmss-name>-hd`". The RSA Public Key is added to the `.ssh/authorized_keys` of the head node.

### Home Folder

The `/home` folder is mounted over NFS and is hosted by the head node. Review `/etc/exports/` for more details.
All the installations (miniconda, tensorflow, horovod) happen in the `/home/<user>` folder which is synced across all compute nodes.

### Compute Nodes

Compute nodes are the actual VMSS. Run the `generateHostFile` script under `/home/<user>/scripts` folder to generate a list of compute nodes that are part of this VMSS. The hostfile will be generated under user's home folder.

*Note*: Please review [`hn-setup.sh`](hn-setup.sh) and [`cn-setup.sh`](cn-setup.sh) for more details on how the head node and compute nodes are configured.

## Running Benchmarks

### Step 1: Login into the "Head Node"
In the Azure portal, go to `Virtual Machines` and click on the "`<vmss-name>-hd`" VM. Find the public IP address and login via SSH using the private key corresponding to the public key used in the template during the launch.

Once you login to the head node, you will be inside a conda envirnoment - `intel-tf-py36` . See the following example.
```
(intel-tf-py36) [azuser@tfbench-hd ~]$
```

### Step 2: Create host file
 Generate a host file with names and private IP's of all the compute nodes. This is create 2 files in your home folder. The benchmark script will use the `/home/<user>/hostiplist` file.

```
cd ~/scripts
./generateHostFile
```
Sample output:
```
(intel-tf-py36) [azuser@tfbench-hd ~]$ cd scripts/

(intel-tf-py36) [azuser@tfbench-hd scripts]$ ls
base36ToDec       generateHostFile  tf-bench-ompi.sh

(intel-tf-py36) [azuser@tfbench-hd scripts]$ ./generateHostFile
status=OK;hosts=2;sshin=2
```

### Step 3: Launch Benchmarks
`~/scripts/tf-bench-ompi.sh` is the script to launch the benchmarks. This will launch `resnet50` model training for 100 batches with 50 warmup batches. [Modify the script here](scripts/tf-bench-ompi.sh#L23) to change either the model or number of batches. Benchmark usage is:
```
./tf-bench-ompi.sh <NUM_NODES> <WORKERS_PER_SOCKET> <BATCH_SIZE> <FABRIC(ib,sock)>
```
 - Example using 4 nodes, 2 workers per sockets, BS=64, and infiniband
```
cd ~/scripts
./tf-bench-ompi.sh 4 2 64 ib
```
- Example using 4 nodes, 2 workers per sockets, BS=64, and sockets
```
cd ~/scripts
./tf-bench-ompi.sh 4 2 64 sock
```

- Example with defaults: NUM_NODES=1, WORKERS_PER_SOCKET=1, BATCH_SIZE=64, FABRIC=sock
```
cd ~/scripts
./tf-bench-ompi.sh
```

### Using HPC-X MPI Library
You will need to edit the `~/.bashrc` file to load the `HPC-X `library instead of `openmpi`.
Open .bashrc  file for editing
```
 vi ~/.bashrc
```
**Replace** the following line
```
module load mpi/openmpi
```
with
```
module load mpi/hpcx
```

**Logout** of the terminal session and login again and launch the benchmarks like in [Step 3](#step-3-launch-benchmarks)

##

## SKU Availability and Locations

Please note that these are specialized SKU types and are not available in all locations. Please refer to [Virtual Machine Availability by Regions](https://azure.microsoft.com/global-infrastructure/services/?products=virtual-machines) to decide on the target location for your deployment.
