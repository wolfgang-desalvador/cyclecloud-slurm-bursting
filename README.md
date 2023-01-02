# Azure CycleCloud Slurm bursting

This repository contains the code required to realize a "lab" for a cloud bursting scenario with Slurm and Azure CycleCloud. The scripts contained in the repository are meant to provide a recipe about how to configure from scratch an external Slurm cluster and then connect it to an Azure CycleCloud instance.

For exisiting clusters it can be used as a guidance of the necessary modifications to Slurm configuration for a bursting scenario configuration.

## Software versions
This flow has been tested with the following stack:
* CentOS HPC Image 7.9 (urn: OpenLogic:CentOS-HPC:7_9-gen2:7.9.2022040101)
* Azure CycleCloud Version 8.3-3062
* Slurm 22.05.3
* Azure CycleCloud Slurm template 2.7.0

## Architecture overview

The architecture proposed in this example is based on the deployment of a Slurm cluster outside of Azure CycleCloud inside an Azure subnet and the subsequent connection of this cluster, using CycleCloud libraries, to an headless Slurm CycleCloud cluster.
<br>
</br>

![Alt text](images/architecture.png?raw=true "Architecture")

## Azure CycleCloud setup

The first step of the procedure is to configure Slurm headless cluster in Azure CycleCloud. This cluster won't have an head node, but it will have execution nodes that will be provisioned/de-provisioned on-demand by Azure CycleCloud.

As a first step it is necessary to import `slurm-headless.txt` inside the designated Azure CycleCloud instance:

`cyclecloud import_template -f slurm-headless.txt`

This will make Slurm headless template available inside Azure CycleCloud

Please refer to official Azure CycleCloud documentation for <a href="https://learn.microsoft.com/en-us/azure/cyclecloud/how-to/install-cyclecloud-cli?view=cyclecloud-8"> Azure CLI Installation details </a>

## Azure CycleCloud cluster creation

After template has been imported in Azure CycleCloud, the Slurm headless cluster can be created following the standard procedure from the UI.

Some key points in the configuration:
* It is critical to have already reserverd the IP Address where the NFS server with shared homes and scheduler configuration files will be hosted. In this lab, this will be the Slurm Head Node in the architecture diagram. 
* Once cluster will be created, no node will be displayed in the UI. This will be required in a later stage
* Annotate the name of the cluster that will be required in external head node connection (`<CLUSTER_NAME>`)

A step by step guide is displayed in order below:
<br>
</br>
![Alt text](images/cluster_creation_1.png?raw=true "Step 1")
<br>
</br>
![Alt text](images/cluster_creation_2.png?raw=true "Step 2")
<br>
</br>
![Alt text](images/cluster_creation_3.png?raw=true "Step 3")
<br>
</br>
![Alt text](images/cluster_creation_4.png?raw=true "Step 4")
<br>
</br>
![Alt text](images/cluster_creation_5.png?raw=true "Step 5")
<br>
</br>
![Alt text](images/cluster_creation_6.png?raw=true "Step 6")
<br>
</br>
![Alt text](images/cluster_creation_7.png?raw=true "Step 7")
<br>
</br>
![Alt text](images/cluster_creation_7.png?raw=true "Step 8")

## Slurm connector user creation

In order for the Slurm head node to authenticate and interact with Azure CycleCloud for node provisioning, it is critical to create an user in Azure CycleCloud and assigning to this user the cluster administrator role on the newly created cluster (credentials will be referred to as `<USERNAME>` and `<PASSWORD>`)


![Alt text](images/connector_user_1.png?raw=true "Slurm Connector Step 1")
<br>
</br>
![Alt text](images/connector_user_2.png?raw=true "Slurm Connector Step 2")
<br>
</br>
![Alt text](images/connector_user_3.png?raw=true "Slurm Connector Step 3")
<br>
</br>
![Alt text](images/connector_user_4.png?raw=true "Slurm Connector Step 4")
<br>
</br>
![Alt text](images/connector_user_5.png?raw=true "Slurm Connector Step 5")
<br>
</br>

## External Slurm head node creation

The external Slurm head node requires an Azure Virtual machine VM to be created with the following requirements:
* Since it will be the NFS Server were Azure CycleCloud and external execution nodes mount `/shared` and `/sched` path, no public IP should be assinged to the VM
* It should be located in a subnet which can access Azure CycleCloud server and related execution nodes on Slurm relevant ports
* It must have users configuration as in Azure CycleCloud, with same UID and GID

After machine creation with standard CentOS marketplace image, the following commands will configure the Slurm head node:


```
sudo ./setup-slurm-cluster.sh -n "Slurm-Cluster" -i <CIDR_NFS_CLIENTS>
```

Users aligned with Azure CycleCloud should be created on the node:

```
mkdir -p /shared/home
groupadd -g <UID> <USERNAME>
useradd -u <UID> -g <UID> -m -d /shared/home/<USERNAME>
```

This should be done for all Azure CycleCloud nodes.

After, the following command must be run for connection with Azure CycleCloud server (remember to Start Azure CyleCloud headless cluster):

```
sudo ./connect-cyclecloud.sh configure-cyclecloud-connection -u <CYCLECLOUD_SLURM_USER> -p <CYCLECLOUD_SLURM_PASSWORD> -l https://<CYCLECLOUD_IP_ADDRESS>:9443 -n <CLUSTER_NAME> -t <CLUSTER_TAG> -s <SUBSCRIPTION_ID>
```

After this command is executed, the nodes will appear in Azure CycleCloud cluster:

![Alt text](images/nodes_creation.png?raw=true "Slurm Nodes creation")
<br>

After this is completed, the execution of a Slurm allocation brings to staging of the resources in Azure CycleCloud and subsequent submission to a node. It is important to use for this a user existing in Azure CycleCloud and paying attention to have visibility of script and input files for the job also on execution nodes.

```
# With a user existing both on Azure CycleCloud and on the head nodes from the Slurm external head node
salloc -N 1
```
![Alt text](images/node_allocation.png?raw=true "Slurm Nodes allocation")
<br>
