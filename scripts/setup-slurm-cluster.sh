#!/bin/bash -e

DEFAULT_NFS_TYPE="internal"
DEFAULT_SHAREDFOLDER="/shared"
DEFAULT_SCHEDFOLDER="/sched"
DEFAULT_SLURM_UID="11100"
DEFAULT_SLURM_GID="11100"
DEFAULT_MUNGE_UID="11101"
DEFAULT_MUNGE_GID="11101"
DEFAULT_SLURM_VERSION="22.05.3"
DEFAULT_IP_RANGE="all"
DEFAULT_PREFIX="slurm-lab-execution-"
DEFAULT_NUMBER_OF_NODES="4"


print_usage_and_exit()
{
   echo ""
   echo "Configure Slurm head node for Azure CycleCloud bursting scenario"
   echo ""
   echo "DESCRIPTION:"
   echo "   Script to set up a Slurm head node and execution nodes ready to be connected"
   echo "   with Azure CycleCloud."
   echo ""
   echo "   This script configures the server or execution nodes installing Slurm, creating"
   echo "   the folder structure and installing all the dependencies for the busting"
   echo "   scenario."
   echo ""
   echo "USAGE: $(basename "$0") <operation_type> <options>"
   echo ""
   echo "OPERATION TYPES:"
   echo "   The first argument to $(basename "$0") is considered to be the operation type that the"
   echo "   script should configure."
   echo ""
   echo "   The following operation types are available:"
   echo ""
   echo "   configure-head-node:"
   echo "      This configures the external slurm head node performing the following operations:"
   echo "      - NFS Server creation with two export (/shared and /sched)"   
   echo "      - Slurm and Munge users creation in accordance with Azure CycleCloud"   
   echo "      - Azure CycleCloud scale lib installation"   
   echo "      - Slurm compilation and installation. RPMs are then shared in /sched for external"   
   echo "        execution nodes"   
   echo ""
   echo "      Mandatory arguments:"
   echo "         -n NAME       => Name of the Slurm cluster."
   echo ""
   echo "      Optional arguments:"
   echo "         -i IP         => CIDR stating where the NFS mount points should be accessible."
   echo "                          Default: ${DEFAULT_IP_RANGE}"
   echo "         -h SHARED     => Shared folder path."
   echo "                          Default: ${DEFAULT_SHAREDFOLDER}"
   echo "         -c SCHED      => Sched folder path."
   echo "                          Default: ${DEFAULT_SCHEDFOLDER}"
   echo "         -u SLURM_UID  => Slurm user UID"
   echo "                          Default: ${DEFAULT_SLURM_UID}"
   echo "         -g SLURM_GID  => Slurm user GID"
   echo "                          Default: ${DEFAULT_SLURM_GID}"
   echo "         -U MUNGE_UID  => Munge user UID"
   echo "                          Default: ${DEFAULT_MUNGE_UID}"
   echo "         -G MUNGE_GID  => Munge user GID"
   echo "                          Default: ${DEFAULT_MUNGE_GID}"
   echo "         -v VERSION    => Slurm Version"
   echo "                          Default: ${DEFAULT_SLURM_VERSION}"
   echo ""
   echo "   configure-execution-node:"
   echo "      This configures the external slurm execution node (must be executed after head node configuraiton)"
   echo "      performing the following operations:"
   echo "      - Mount from head node NFS Server of (/shared and /sched)"   
   echo "      - Slurm and Munge users creation in accordance with Azure CycleCloud"   
   echo "      - Slurm installation from RPMs in /sched (created from head node configuration)"   
   echo ""
   echo "      Mandatory arguments:"
   echo "         -s NFS_SERVER => NFS server IP, should be IP/FQDN of head node"
   echo ""
   echo "      Optional arguments:"
   echo "         -h SHARED     => Shared folder path."
   echo "                          Default: ${DEFAULT_SHAREDFOLDER}"
   echo "         -c SCHED      => Sched folder path."
   echo "                          Default: ${DEFAULT_SCHEDFOLDER}"
   echo "         -u SLURM_UID  => Slurm user UID"
   echo "                          Default: ${DEFAULT_SLURM_UID}"
   echo "         -g SLURM_GID  => Slurm user GID"
   echo "                          Default: ${DEFAULT_SLURM_GID}"
   echo "         -U MUNGE_UID  => Munge user UID"
   echo "                          Default: ${DEFAULT_MUNGE_UID}"
   echo "         -G MUNGE_GID  => Munge user GID"
   echo "                          Default: ${DEFAULT_MUNGE_GID}"
   echo ""
   echo "   add-external-execution-nodes:"
   echo "      This will create definition of additional execution nodes external to Azure CycleCloud to test bursting"   
   echo "      scenario."   
   echo ""
   echo "      Mandatory arguments:"
   echo "         -M REAL_MEMORY        => Real memory of external execution nodes in KiB"
   echo "         -C NUMBER_OF_CPUS     => Number of CPUs of external execution nodes"
   echo "         -T NUMBER_OF_THREADS  => Number of threads per cpu of the external execution nodes"
   echo ""
   echo "      Optional arguments:"
   echo "         -c SCHED      => Sched folder path."
   echo "                          Default: ${DEFAULT_SCHEDFOLDER}"
   echo "         -P PREFIX     => Prefix of the external execution nodes to be added"
   echo "                          Default: ${DEFAULT_PREFIX}"
   echo "         -N NODES      => Number of external nodes to be added"
   echo "                          Default: ${NUMBER_OF_NODES}"
   echo ""
   echo "EXAMPLES:"
   echo ""
   echo "   Configure head node with default configuration and limiting connections to NFS on 10.0.0.0/24:"
   echo "      $(basename "$0") configure-head-node -n Slurm-Cluster -i 10.0.0.0/24"
   echo ""
   echo "   Configure execution node with default configuration and connecting to head node at 10.0.0.4:"
   echo "      $(basename "$0") configure-execution-node -s 10.0.0.4"
   echo ""
   echo "   Add 6 external execution nodes to Slurm configuration"
   echo "      $(basename "$0") add-external-execution-nodes -N 6 -P slurm-external-execution-node -C 2 -M 4096 -T 1" 
   exit 1
}


create_users() {
    MUNGE_UID=$1
    MUNGE_GID=$2
    SLURM_UID=$3
    SLURM_GID=$4
    groupadd munge -g ${MUNGE_GID}
    useradd munge -g ${MUNGE_GID} -s /bin/false -M -u ${MUNGE_UID}

    groupadd slurm -g ${SLURM_GID}
    useradd slurm -g ${SLURM_GID} -M -u ${SLURM_UID}
}


mount_nfs_server()
{
   SCHED_FOLDER=$3
   SHARED_FOLDER=$2
   NFS_SERVER=$1

   yum install -y nfs-utils

   mkdir -p ${SHARED_FOLDER}
   mkdir -p ${SCHED_FOLDER}
   if cat /etc/fstab | grep "${NFS_SERVER}:${SHARED_FOLDER}";
   then
       echo "Mount point already present"
   else
       echo "${NFS_SERVER}:${SHARED_FOLDER}    ${SHARED_FOLDER}    nfs    defaults    0 0 " >> /etc/fstab 
   fi
   if cat /etc/fstab | grep "${NFS_SERVER}:${SCHED_FOLDER}";
   then
       echo "Mount point already present"
   else
       echo "${NFS_SERVER}:${SCHED_FOLDER}    ${SCHED_FOLDER}    nfs    defaults    0 0 " >> /etc/fstab
   fi
   mount -a
}

configure_nfs_server()
{
   SCHED_FOLDER=$3
   SHARED_FOLDER=$2
   IP_RANGE=$1

    yum install -y nfs-utils

    mkdir -p ${SHARED_FOLDER}
    mkdir -p ${SCHED_FOLDER}
   if [[ "${IP_RANGE}" == "all" ]]
   then
      echo "${SHARED_FOLDER} *(rw,sync,no_root_squash)" >> /etc/exports
      echo "${SCHED_FOLDER} *(rw,sync,no_root_squash)" >> /etc/exports
   else
      echo "${SHARED_FOLDER} ${IP_RANGE}(rw,sync,no_root_squash)" >> /etc/exports
      echo "${SCHED_FOLDER} ${IP_RANGE}(rw,sync,no_root_squash)" >> /etc/exports
   fi

    systemctl start nfs-server
    systemctl enable nfs-server
}

configure_munge()
{
    SCHED_FOLDER=$1
    EXCUTE_NODE=$2
    yum install -y epel-release
    yum install -y munge

   if [ "${EXCUTE_NODE}" = "false" ]
   then

        mkdir -p ${SCHED_FOLDER}/munge/
        dd if=/dev/urandom bs=1 count=1024 > ${SCHED_FOLDER}/munge/munge.key
        chown munge:munge ${SCHED_FOLDER}/munge/munge.key
        chmod 700 ${SCHED_FOLDER}/munge/munge.key
    fi
    cp -p ${SCHED_FOLDER}/munge/munge.key  /etc/munge/munge.key 
    chown munge:munge /etc/munge/munge.key

    systemctl enable munge
    systemctl restart munge
}



build_slurm() {
    SCHED_FOLDER=$1
    SLURM_VERSION=$2
    wget https://raw.githubusercontent.com/Azure/cyclecloud-slurm/master/specs/default/cluster-init/files/00-build-slurm.sh -O 00-build-slurm.sh
    chmod +x 00-build-slurm.sh
    sed -i '/build_slurm /d' 00-build-slurm.sh
    source ./00-build-slurm.sh
    build_slurm centos ${SLURM_VERSION}
    cp -r /root/rpmbuild/RPMS/x86_64 ${SCHED_FOLDER}/slurm_rpms    
}

install_slurm() {
    SCHED_FOLDER=$1
    
    cd ${SCHED_FOLDER}/slurm_rpms
    yum localinstall -y slurm-*.rpm
}

create_links_and_folders() 
{
    SCHED_FOLDER=$1
    rm -f /etc/slurm/slurm.conf

    sudo ln -s ${SCHED_FOLDER}/slurm.conf /etc/slurm/slurm.conf
    sudo ln -s ${SCHED_FOLDER}/gres.conf /etc/slurm/gres.conf
    sudo ln -s ${SCHED_FOLDER}/topology.conf /etc/slurm/topology.conf 
    sudo ln -s ${SCHED_FOLDER}/cyclecloud.conf /etc/slurm/cyclecloud.conf
    sudo ln -s ${SCHED_FOLDER}/keep_alive.conf /etc/slurm/keep_alive.conf
    sudo ln -s ${SCHED_FOLDER}/cgroup.conf /etc/slurm/cgroup.conf

    mkdir -p /var/spool/slurmd
    mkdir -p /var/log/slurmd
    mkdir -p /var/log/slurmctld

    chown slurm:slurm /var/spool/slurmd
    chown slurm:slurm /var/log/slurmd
    chown slurm:slurm /var/log/slurmctld

}

configure_slurm()
{
    CLUSTER_NAME=$1
    SCHED_FOLDER=$2
    wget https://raw.githubusercontent.com/Azure/cyclecloud-slurm/master/specs/default/chef/site-cookbooks/slurm/files/default/job_submit.lua -O /etc/slurm/job_submit.lua

    echo "# this file is managed by cyclecloud-slurm" > ${SCHED_FOLDER}/cyclecloud.conf
    echo "# this file is managed by cyclecloud-slurm" > ${SCHED_FOLDER}/keep_alive.conf
    chown slurm:slurm ${SCHED_FOLDER}/cyclecloud.conf
    chown slurm:slurm ${SCHED_FOLDER}/keep_alive.conf



    cat <<EOF > ${SCHED_FOLDER}/slurm.conf
MpiDefault=none
ProctrackType=proctrack/cgroup
ReturnToService=2
PropagateResourceLimits=ALL
SlurmctldPidFile=/var/run/slurmctld.pid
SlurmdPidFile=/var/run/slurmd.pid
SlurmdSpoolDir=/var/spool/slurmd
SlurmUser="slurm"
StateSaveLocation=/var/spool/slurmd
SwitchType=switch/none
TaskPlugin=task/affinity,task/cgroup
SchedulerType=sched/backfill
SelectType=select/cons_tres
GresTypes=gpu
SelectTypeParameters=CR_Core_Memory
ClusterName="${CLUSTER_NAME}"
JobAcctGatherType=jobacct_gather/none
SlurmctldDebug=debug
SlurmctldLogFile=/var/log/slurmctld/slurmctld.log
SlurmctldParameters=idle_on_node_suspend
SlurmdDebug=debug
SlurmdLogFile=/var/log/slurmd/slurmd.log
TopologyPlugin=topology/tree
JobSubmitPlugins=lua
PrivateData=cloud
TreeWidth=65533
ResumeTimeout=1800
SuspendTimeout=600
SuspendTime=300
ResumeProgram=/opt/cycle/slurm/resume_program.sh
ResumeFailProgram=/opt/cycle/slurm/resume_fail_program.sh
SuspendProgram=/opt/cycle/slurm/suspend_program.sh
SchedulerParameters=max_switch_wait=24:00:00
AccountingStorageType=accounting_storage/none
Include cyclecloud.conf
Include keep_alive.conf
EOF


    host=$(hostname -s)
    grep -q "SlurmctldHost=$host" ${SCHED_FOLDER}/slurm.conf && exit 0
    grep -v SlurmctldHost ${SCHED_FOLDER}/slurm.conf > ${SCHED_FOLDER}/slurm.conf.tmp
    printf "\nSlurmctldHost=$host\n" >> ${SCHED_FOLDER}/slurm.conf.tmp
    mv -f ${SCHED_FOLDER}/slurm.conf.tmp ${SCHED_FOLDER}/slurm.conf

    cat <<EOF > ${SCHED_FOLDER}/cgroup.conf
CgroupAutomount=no
#CgroupMountpoint=/sys/fs/cgroup
ConstrainCores=yes
ConstrainRamSpace=yes
# This setting can be problematic with GPU skus
# ConstrainSwapSpace=yes
ConstrainDevices=yes
EOF

    chown -R slurm:slurm ${SCHED_FOLDER}/*.conf
    chmod -R 0644 ${SCHED_FOLDER}/*.conf

    create_links_and_folders ${SCHED_FOLDER}


    cat <<EOF > /etc/security/limits.d/slurm-limits.conf
*               soft    memlock            unlimited
*               hard    memlock            unlimited
EOF

    mkdir -p /etc/systemd/system/slurmctld.service.d
    cat <<EOF > /etc/systemd/system/slurmctld.service.d/override.conf
[Service]
WorkingDirectory=/var/log/slurmctld
EOF

}

add_external_nodes()
{
   PREFIX=$1
   NUMBER_OF_NODES=$2
   NUMBER_OF_CPUS=$3
   NUMBER_OF_THREADS=$4
   REAL_MEMORY=$5
   echo "SwitchName=onp Nodes=${PREFIX}-[1-${NUMBER_OF_NODES}]" >> /sched/topology.conf
   sed -i "s/PartitionName=hpc Nodes=/PartitionName=hpc Nodes=${PREFIX}-[1-${NUMBER_OF_NODES}],/" /sched/cyclecloud.conf
   sed -i "/PartitionName=hpc/a Nodename=${PREFIX}-[1-${NUMBER_OF_NODES}] CPUs=${NUMBER_OF_CPUS} ThreadsPerCore=${NUMBER_OF_THREADS} RealMemory=$(bc -l <<<$REAL_MEMORY - 1024)" /sched/cyclecloud.conf

   systemctl restart slurmctld
}

add_execution_nodes()
{
SCHED_FOLDER=${DEFAULT_SCHEDFOLDER}
PREFIX=${DEFAULT_PREFIX}
NUMBER_OF_NODES=${DEFAULT_NUMBER_OF_NODES}
NUMBER_OF_CPUS="false"
NUMBER_OF_THREADS="false"
REAL_MEMORY="false"

while getopts ":c:p:N:M:C:T" opt; do
      case $opt in
         c)
            SCHED_FOLDER=${OPTARG}
         ;;
         p)
            PREFIX=${OPTARG}
         ;;
         N)
            NUMBER_OF_NODES=${OPTARG}
         ;;
         M)
            REAL_MEMORY=${OPTARG}
         ;;
         C)
            NUMBER_OF_CPUS=${OPTARG}
         ;;  
         T)
            NUMBER_OF_THREADS=${OPTARG}
         ;;          
         \?)
            echo "ERROR: invalid option: -${OPTARG}" >&2
            print_usage_and_exit
         ;;
         :)
            echo "ERROR: Option -${OPTARG} requires an argument" >&2
            print_usage_and_exit
         ;;
      esac
   done
   
   if [[ "${REAL_MEMORY}" == "false" || "${NUMBER_OF_CPUS}" == "false" || "${NUMBER_OF_THREADS}" == "false" ]]
   then
       echo "Not all node parameters (memory, number of cpus and number of threads) specified. Exiting..."
       exit 1
   fi

   add_external_nodes ${PREFIX} ${NUMBER_OF_NODES} ${NUMBER_OF_CPUS} ${NUMBER_OF_THREADS} ${REAL_MEMORY}
}

configure_head()
{
   CLUSTER_NAME="false"
   SLURM_UID=${DEFAULT_SLURM_UID}
   SLURM_GID=${DEFAULT_SLURM_GID}
   MUNGE_UID=${DEFAULT_MUNGE_UID}
   MUNGE_GID=${DEFAULT_MUNGE_GID}
   SCHED_FOLDER=${DEFAULT_SCHEDFOLDER}
   SHARED_FOLDER=${DEFAULT_SHAREDFOLDER}
   SLURM_VERSION=${DEFAULT_SLURM_VERSION}
   IP_RANGE=${DEFAULT_IP_RANGE}


while getopts ":n:u:g:U:G:i:v:p" opt; do
      case $opt in
         n)
            CLUSTER_NAME=${OPTARG}
         ;;
         u)
            SLURM_UID=${OPTARG}
         ;;
         g)
            SLURM_GID=${OPTARG}
         ;;
         U)
            MUNGE_UID=${OPTARG}
         ;;
         G)
            MUNGE_GID=${OPTARG}
         ;;
         i)
            IP_RANGE=${OPTARG}
         ;;
         v)
            SLURM_VERSION=${OPTARG}
         ;;
         \?)
            echo "ERROR: invalid option: -${OPTARG}" >&2
            print_usage_and_exit
         ;;
         :)
            echo "ERROR: Option -${OPTARG} requires an argument" >&2
            print_usage_and_exit
         ;;
      esac
   done

configure_nfs_server ${IP_RANGE} ${SHARED_FOLDER} ${SCHED_FOLDER}

create_users ${MUNGE_UID} ${MUNGE_GID} ${SLURM_UID} ${SLURM_GID}

configure_munge ${SCHED_FOLDER} "false"

build_slurm ${SCHED_FOLDER} ${SLURM_VERSION}

install_slurm ${SCHED_FOLDER} 

configure_slurm ${CLUSTER_NAME} ${SCHED_FOLDER}
}

configure_execute()
{
   CLUSTER_NAME="false"
   SLURM_UID=${DEFAULT_SLURM_UID}
   SLURM_GID=${DEFAULT_SLURM_GID}
   MUNGE_UID=${DEFAULT_MUNGE_UID}
   MUNGE_GID=${DEFAULT_MUNGE_GID}
   SCHED_FOLDER=${DEFAULT_SCHEDFOLDER}
   SHARED_FOLDER=${DEFAULT_SHAREDFOLDER}
   SLURM_VERSION=${DEFAULT_SLURM_VERSION}
   NFS_SERVER="false"

while getopts ":s:u:g:U:G" opt; do
      case $opt in
         s)
            NFS_SERVER=${OPTARG}
         ;;
         u)
            SLURM_UID=${OPTARG}
         ;;
         g)
            SLURM_GID=${OPTARG}
         ;;
         U)
            MUNGE_UID=${OPTARG}
         ;;
         G)
            MUNGE_GID=${OPTARG}
         ;;
         \?)
            echo "ERROR: invalid option: -${OPTARG}" >&2
            print_usage_and_exit
         ;;
         :)
            echo "ERROR: Option -${OPTARG} requires an argument" >&2
            print_usage_and_exit
         ;;
      esac
   done

if [[ "${NFS_SERVER}" == "false" ]]
then
    echo "NFS IP Server not specified. Exiting..."
    exit 1
fi

mount_nfs_server ${NFS_SERVER} ${SHARED_FOLDER} ${SCHED_FOLDER}

create_users ${MUNGE_UID} ${MUNGE_GID} ${SLURM_UID} ${SLURM_GID}

configure_munge ${SCHED_FOLDER} "true"

install_slurm ${SCHED_FOLDER} ${SLURM_VERSION}

create_links_and_folders ${SCHED_FOLDER}

systemctl enable slurmd --now

}



# print help if no arguments given
if [ $# -eq 0 ] ; then
   print_usage_and_exit
fi


# parse arguments
NODE_TYPE=$1

if [ "${NODE_TYPE}" = "configure-head-node" ]
then
   shift
   configure_head "$@"
elif [ "${NODE_TYPE}" = "configure-execution-node" ]
then
   shift
   configure_execute "$@"
elif [ "${NODE_TYPE}" = "add-external-execution-nodes" ]
then
   shift
   add_execution_nodes "$@"
else
   print_usage_and_exit
fi
