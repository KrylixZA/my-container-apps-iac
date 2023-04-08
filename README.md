# my-container-apps-iac

[![Build Status](https://dev.azure.com/headleysj/Demos/_apis/build/status%2FKrylixZA.my-container-apps-iac?branchName=main)](https://dev.azure.com/headleysj/Demos/_build/latest?definitionId=16&branchName=main)

A simple Terraform repo to spin up resources to get a basic environment running in Azure where the main compute is Azure Container Apps.

This provisions the resources to deploy the resources in my [dapr-demo](https://github.com/KrylixZA/dapr-demo) repository. The main two components I'll be deploying are:

* Order API
* Garbage Collector
