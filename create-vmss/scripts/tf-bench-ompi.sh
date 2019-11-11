#!/bin/bash

#usage: ./tf-bench-impi.sh <NUM_NODES> <WORKERS_PER_SOCKET> <BATCH_SIZE> <FABRIC(ib,sock)>
# If WORKERS_PER_SOCKET=0, then WORKERS_PER_NODE=1

# Example using 4 nodes, 2 workers per sockets, BS=64, and infiniband
# ./tf-bench-impi.sh 4 2 64 ib

# Example using 4 nodes, 2 workers per sockets, BS=64, and sockets
# ./tf-bench-impi.sh 4 2 64 sock

# Save the logs
# ./tf-bench-impi.sh 4 2 64 ib 2>&1 | tee tfmn-2n-64b-ib.log

# Example with defaults: NUM_NODES=1, WORKERS_PER_SOCKET=1, BATCH_SIZE=64, FABRIC=sock
# ./tf-bench-impi.sh

NUM_NODES=${1:-1}
WORKERS_PER_SOCKET=${2:-1}
BATCH_SIZE=${3:-64}
FABRIC=${4:-sock}

NUM_WARMUP_BATCHES=50
NUM_BATCHES=100
MODEL=resnet50
#MODEL=alexnet
INTER_T=2

HOST_FILE="/home/$USER/hostiplist"
if [ ! -f "$HOST_FILE" ]; then
    echo "$HOST_FILE is missing. Generate the file by running: /home/$USER/scripts/generateHostFile "
    exit 1
fi

TF_BENCH_SCRIPT_PATH="/home/$USER/benchmarks/scripts/tf_cnn_benchmarks/tf_cnn_benchmarks.py"
if [ ! -f "$TF_BENCH_SCRIPT_PATH" ]; then
    echo "Unable to find TF Benchmarks at $TF_BENCH_SCRIPT_PATH . If you used the following to deploy, the benchmarks should have been installed. https://github.com/ravi9/azhpc-templates/blob/tf-bench-impi/create-vmss/README.md "
    exit 1
fi

TF_RECORDS_DIR="/mnt/resource/scratch/ilsvrc2012_tfrecords_20of1024"
DATA_ARG="--data_dir=${TF_RECORDS_DIR} --data_name=imagenet "

if [ ! -d "$TF_RECORDS_DIR" ]; then
    echo "Imagenet sample dataset directory not found at $TF_RECORDS_DIR . Will benchmark with dummy/synthetic data..."
    DATA_ARG="--data_name=imagenet "
    sleep 3s
fi

NUM_SOCKETS=`lscpu | grep "Socket(s)" | cut -d':' -f2 | xargs`
CORES_PER_SOCKET=`lscpu | grep "Core(s) per socket" | cut -d':' -f2 | xargs`

if (( $WORKERS_PER_SOCKET == 0 )); then
    CORES_PER_WORKER=$((CORES_PER_SOCKET * NUM_SOCKETS))
    WORKERS_PER_NODE=1
else
    CORES_PER_WORKER=$((CORES_PER_SOCKET / WORKERS_PER_SOCKET))
    WORKERS_PER_NODE=$((WORKERS_PER_SOCKET * NUM_SOCKETS))
fi

INTRA_T=$((CORES_PER_WORKER / INTER_T))
OMP_NUM_THREADS=$INTRA_T
TOTAL_WORKERS=$((NUM_NODES * WORKERS_PER_NODE))

echo "#############################"
echo "TOTAL_NODES: $NUM_NODES"
echo "WORKERS_PER_NODE: $WORKERS_PER_NODE"
echo "TOTAL_WORKERS: $TOTAL_WORKERS"
echo "CORES_PER_WORKER: $CORES_PER_WORKER"
echo "OMP_NUM_THREADS: $OMP_NUM_THREADS"
echo "NUM_INTRA_THREADS: $INTRA_T"
echo "NUM_INTER_THREADS: $INTER_T"
echo "#############################"

export OMP_NUM_THREADS=$OMP_NUM_THREADS

TF_ARGS=" \
 --batch_size=${BATCH_SIZE} \
 --num_warmup_batches=${NUM_WARMUP_BATCHES} \
 --num_batches=${NUM_BATCHES} \
 --model=${MODEL} \
 --num_intra_threads=${INTRA_T} \
 --num_inter_threads=${INTER_T} \
 ${DATA_ARG} \
 --kmp_blocktime=1 \
 --kmp_affinity=granularity=fine,noverbose,compact,1,0 \
 --display_every=10 \
 --data_format=NCHW \
 --optimizer=momentum \
 --forward_only=False \
 --device=cpu \
 --mkl=TRUE \
 --variable_update=horovod \
 --horovod_device=cpu \
 --local_parameter_device=cpu "

echo -e "TF Common Args: $args"

if [ "${FABRIC}" == "ib" ]; then
    FABRIC_ARGS="-mca pml ucx \
    --mca btl ^vader,tcp,openib \
    -mca coll_hcoll_enable 1 \
    -x HCOLL_MAIN_IB=mlx5_0:1 \
    -x UCX_NET_DEVICES=mlx5_0:1 \
    -x UCX_IB_PKEY=`cat /sys/class/infiniband/mlx5_0/ports/1/pkeys/0 | sed 's/\(.\{2\}\)./\10/'` \
    -x UCX_TLS=rc_x,sm,self "
else
    FABRIC_ARGS="-mca pml ^ucx "
fi

echo -e "Fabric Args: $FABRIC_ARGS"

run_cmd="mpirun \
--oversubscribe -np ${TOTAL_WORKERS} \
-hostfile ${HOST_FILE} \
--map-by ppr:${WORKERS_PER_SOCKET}:socket:pe=${CORES_PER_WORKER} \
${FABRIC_ARGS} \
-x OMP_NUM_THREADS=$OMP_NUM_THREADS \
-x HOROVOD_FUSION_THRESHOLD=134217728 \
-x HOROVOD_MPI_THREADS_DISABLE=1 \
-x PATH=$PATH \
-x LD_LIBRARY_PATH=$LD_LIBRARY_PATH \
python $TF_BENCH_SCRIPT_PATH \
$TF_ARGS "

echo "--------------------------"
echo -e "$run_cmd"

$run_cmd
