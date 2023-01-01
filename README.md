# Azure CycleCloud Slurm bursting

This repository contains the code required to realize a "lab" for a cloud bursting scenario with Slurm and Azure CycleCloud. The scripts contained in the repository are meant to provide a recipe about how to configure from scratch an external Slurm cluster and then connect it to an Azure CycleCloud instance.

For exisiting clusters it can be used as a guidance of the necessary modifications to Slurm configuration for a bursting scenario configuration.

## Architecture overview

The architecture proposed in this example is based on the deployment of a Slurm cluster outside of Azure CycleCloud inside an Azure subnet and the subsequent connection of this cluster, using CycleCloud libraries, to an headless Slurm CycleCloud cluster.
<br>
</br>

![Alt text](images/architecture.png?raw=true "Architecture")