#!/bin/bash -e

DEFAULT_NFS_TYPE="internal"
DEFAULT_SHAREDFOLDER="/shared"
DEFAULT_SCHEDFOLDER="/sched"
DEFAULT_CYCLECLOUD_SLURM_FOLDER="/opt/cycle"
DEFAULT_SLURM_UID="11100"
DEFAULT_SLURM_GID="11100"


print_usage_and_exit()
{
   echo ""
   echo "Connnect external Slurm head node for Azure CycleCloud bursting scenario"
   echo ""
   echo "DESCRIPTION:"
   echo "   Script to connect a Slurm head node with Azure CycleCloud."
   echo ""
   echo "   This script connects the server with Slurm with Azure CycleCloud, creating"
   echo "   Slurm configuration file relevant for the bursting scenario"
   echo ""
   echo "USAGE: $(basename "$0") <operation_type> <options>"
   echo ""
   echo "OPERATION TYPES:"
   echo "   The first argument to $(basename "$0") is considered to be the operation type that the"
   echo "   script should execute."
   echo ""
   echo "   The following operation types are available:"
   echo ""
   echo "   configure-cyclecloud-connection:"
   echo "      This connects the head node to Azure CycleCloud after head node configuration and credentials initialization"
   echo "      for cyclecloud_slurm (to be done separately. It will perform the following operations:"
   echo "      - Create the Slurm nodes in Azure CycleCloud cluster"   
   echo "      - Create all Slurm configuration files according to Azure CycleCloud requirements"     
   echo ""
   echo "      Mandatory arguments:"
   echo "         -u USERNAME        => Real memory of external execution nodes in KiB"
   echo "         -p PASSWORD        => Number of CPUs of external execution nodes"
   echo "         -l URL             => Azure CycleCloud API URL"
   echo "         -n CLUSTER_NAME    => Azure CycleCloud cluster name"
   echo "         -t TAG             => Azure CycleCloud Cluster Tag"
   echo "         -s SUBSCRIPTION    => Azure Subscription ID"
   echo ""
   echo "      Optional arguments:"
   echo "         -c SCHED         => Sched folder path."
   echo "                             Default: ${DEFAULT_SCHEDFOLDER}"
   echo "         -g CYCLE_FOLDER  => Default Azure CycleCloud lib folder"
   echo "                             Default: ${DEFAULT_CYCLECLOUD_SLURM_FOLDER}"
   echo ""
   echo "EXAMPLES:"
   echo ""
   echo ""
   echo "   Connect head node to Azure CycleCloud (requires configuration and parameters from Azure CycleCloud server"
   echo "      $(basename "$0") configure-cyclecloud-connection -u slurm-connector-user -p super_secret -l https://10.3.0.4:9443 \ "
   echo "       -n slurm-bursting -t slurm-bursting(name.surname@slurm-lab-cc:aaaa1234) -s aaaaaaaa-bbbb-1234-cccc-dddddddddddd" 
   exit 1
}


install_cyclecloud_slurm()
{
    CYCLECLOUD_SLURM_FOLDER=$1
    python3 -m venv ${CYCLECLOUD_SLURM_FOLDER}/cycle_python
    source ${CYCLECLOUD_SLURM_FOLDER}/cycle_python/bin/activate
    wget https://github.com/Azure/cyclecloud-slurm/releases/download/2.7.0/cyclecloud_api-8.1.0-py2.py3-none-any.whl
    pip3 install cyclecloud_api-8.1.0-py2.py3-none-any.whl

    mkdir -p ${CYCLECLOUD_SLURM_FOLDER}/slurm
    cd ${CYCLECLOUD_SLURM_FOLDER}/slurm
    git clone https://github.com/Azure/cyclecloud-slurm.git
    cp -r ${CYCLECLOUD_SLURM_FOLDER}/slurm/cyclecloud-slurm/specs/default/chef/site-cookbooks/slurm/files/default/* ${CYCLECLOUD_SLURM_FOLDER}/slurm
    sed -i "s%/opt/cycle/jetpack/system/embedded/bin/python%${CYCLECLOUD_SLURM_FOLDER}/cycle_python/bin/python%g" ${CYCLECLOUD_SLURM_FOLDER}/slurm/cyclecloud_slurm.sh
    sed -i "s%/opt/cycle/jetpack%${CYCLECLOUD_SLURM_FOLDER}%g" ${CYCLECLOUD_SLURM_FOLDER}/slurm/cyclecloud_slurm.py
    chown -R slurm:slurm ${CYCLECLOUD_SLURM_FOLDER}/slurm/
    chmod +x ${CYCLECLOUD_SLURM_FOLDER}/slurm/*.sh
}


configure_cyclecloud_connection()
{
    SCHED_FOLDER=$1
    CYCLECLOUD_SLURM_FOLDER=$2
    USERNAME=$3
    PASSWORD=$4
    URL=$5
    CLUSTER_NAME=$6
    TAG=$7
    SUBSCRIPTION=$8
    mkdir -p ${CYCLECLOUD_SLURM_FOLDER}/config
    
    ${CYCLECLOUD_SLURM_FOLDER}/slurm/cyclecloud_slurm.sh initialize --cluster-name=${CLUSTER_NAME} \
                                                     --username=${USERNAME} \
                                                     --password=${PASSWORD}\
                                                     --url=${URL} \
                                                     --accounting-tag-name ClusterId \
                                                     --accounting-tag-value ${TAG} \
                                                     --accounting-subscription-id ${SUBSCRIPTION}
    
    ${CYCLECLOUD_SLURM_FOLDER}/slurm/cyclecloud_slurm.sh create_nodes --policy Error
    ${CYCLECLOUD_SLURM_FOLDER}/slurm/cyclecloud_slurm.sh slurm_conf > ${SCHED_FOLDER}/cyclecloud.conf
    ${CYCLECLOUD_SLURM_FOLDER}/slurm/cyclecloud_slurm.sh gres_conf > ${SCHED_FOLDER}/gres.conf
    ${CYCLECLOUD_SLURM_FOLDER}/slurm/cyclecloud_slurm.sh topology > ${SCHED_FOLDER}/topology.conf
    
    chown -R slurm:slurm ${SCHED_FOLDER}/*

    systemctl restart munge
    systemctl enable slurmctld
    systemctl restart slurmctld

    echo "*/2 * * * * /opt/cycle/slurm/return_to_idle.sh /var/logs/return_to_idle.log" >> /var/spool/cron/root
}

connect_head()
{
SCHED_FOLDER=${DEFAULT_SCHEDFOLDER}
CYCLECLOUD_SLURM_FOLDER=${DEFAULT_CYCLECLOUD_SLURM_FOLDER}
USERNAME="false"
PASSWORD="false"
URL="false"
CLUSTER_NAME="false"
TAG="false"
SUBSCRIPTION="false"

while getopts ":u:p:l:n:t:s:c:g" opt; do
      case $opt in
         u)
            USERNAME=${OPTARG}
         ;;
         p)
            PASSWORD=${OPTARG}
         ;;
         l)
            URL=${OPTARG}
         ;;
         n)
            CLUSTER_NAME=${OPTARG}
         ;;
         t)
            TAG=${OPTARG}
         ;;  
         s)
            SUBSCRIPTION=${OPTARG}
         ;;
         c)
            SCHED_FOLDER=${OPTARG}
         ;; 
         g)
            CYCLECLOUD_SLURM_FOLDER=${OPTARG}
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
   
   if [[ "${USERNAME}" == "false" || "${PASSWORD}" == "false" || "${URL}" == "false" || "${CLUSTER_NAME}" == "false" || "${TAG}" == "false"  || "${SUBSCRIPTION}" == "false" ]]
   then
       echo "Not all connection parameters specified. Exiting..."
       exit 1
   fi
   
   install_cyclecloud_slurm ${CYCLECLOUD_SLURM_FOLDER}
   configure_cyclecloud_connection ${SCHED_FOLDER} ${CYCLECLOUD_SLURM_FOLDER} ${USERNAME} ${PASSWORD} ${URL} ${CLUSTER_NAME} ${TAG} ${SUBSCRIPTION}
}



# print help if no arguments given
if [ $# -eq 0 ] ; then
   print_usage_and_exit
fi


# parse arguments
ACTION_TYPE=$1

if [ "${ACTION_TYPE}" = "configure-cyclecloud-connection" ]
then
   shift
   connect_head "$@"
else
   print_usage_and_exit
fi
