# kube-secrets-azure-demo
Showcases Kubernetes cluster deployment in Azure using least privilege principle and secure secrets storage. Mounts an Azure Key Vault and connects an Azure Container Registry.

## Deployment
Since the `hashicorp/kubernetes` terraform provider relies on a pre-existing valid credential set, this project needs to be deployed in two stages. You can do this as follows (documented [here](https://github.com/hashicorp/terraform-provider-kubernetes/blob/main/_examples/aks/README.md)).

1. (Optional) Start by creating your `terraform.tfvars` file and filling out the variables and secrets.
2. Initialize your terraform environment.
   ```bash
   terraform init

2. Deploy the _azure_ module first, using the command below. You may be met with a warning message `Warning: Resource targeting is in effect`.

   ```bash
   terraform apply -target=module.azure
   
3. Upon successful deployment, deploy the kubernetes module (and the rest).

   ```bash
   terraform apply

4. To access your newly created cluster and interact with it, you will need an `Azure Kubernetes Service RBAC` role assignment.

## Azure authentication & RBAC
This project assumes you have a Service Principal and are authenticating with a Client ID and Secret. Service Principle must be able to deploy resources in an **existing** Resource Group. With the recent RBAC update, it is possible to limit the number of assignable roles. The RBAC roles used in this project are:

- 7f951dda-4ed3-4680-a7ca-43fe172d538d (AcrPull)
- b86a8fe4-44ce-4948-aee5-eccb2c155cd7 (Key Vault Secrets Officer)
- 4633458b-17de-408a-b874-0445c86b69e6 (Key Vault Secrets User)
- f1a07417-d97a-45cb-824c-7a7467783830 (Managed Identity Operator)

## Github personal access token
The container registry build task requires a Github PAT. Fine grained can be used. I've used a token with the following repository permissions:

- Read access to actions, administration, code, commit statuses, deployments, and metadata 
- Read and Write access to repository hooks

## ID? Client ID? Object ID? Principal ID?
User assigned identity (including system managed identities) resources have multiple ID properties. The `ID` property of an identity resource contains what is essentially a path to the resource, compiled from the Subscription ID, Resource Group name and the resource (identity) name. The `Client ID` and `Object ID` (also known as `Principal ID`) properties contain a GUID which each refers to separate properties. A Client ID for a service principal may refer to an App Registration (or `AppId` in Microsoft Graph), whereas an Object/Principal ID refers to Azure AD.