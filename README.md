# Azure-ArcVM-ESU

This repo is a set of Runbooks that allows you to schedule creation and assignment of ESU Licenses for Windows Server 2012 or Windows Server 2012 R2.
It creates a Automantion account and two runbooks, one for creation and one for deactivation licenses, 

*Quick start:*

* Prerequisites:
```bash
# Create a resource group
$ az group create --location westeurope --name ESU-rg

$ git clone https://github.com/latj/Azure-ArcVM-ESU.git
...
$ cd Azure-ArcVM-ESU/bicep
```

* Deploy :
```bash
$ az deployment group create --resource-group ESU-rg --template-file main.bicep
```

* Post-deploy :
You need to give the Managed Identity (System-managed) for the Automation Account. 