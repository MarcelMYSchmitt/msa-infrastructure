# Introduction 
This project currently contains our infrastructure script and all arm templates for creating an eventhub, storage account, application insights and docker registry.

Eventhub and Storage Account are used for receiving messages, Application Insights is used for sending metrics to our grafana, +
the docker registry is the place where we store our images.

For creating an aks we are going to use the azure cli. You can find the specific commands in the aks folder. 

# Getting Started

Running locally:   
Login using Login-AzureRmAccount and execute `Create-Infrastructure.ps1` with parameter -FileName ms-we-dev-msa.

Running in Azure Devops:
Use the pipeline and edit the parameter. 