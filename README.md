# kube-secrets-azure-demo
Showcases Kubernetes cluster deployment in Azure using least privilege principle and secure secrets storage.

## Azure authentication & RBAC
This project assumes you have a Service Principal and are authenticating with a Client ID and Secret. Service Principle must be able to deploy resources in an **existing** Resource Group. With the recent RBAC update, it is possible to limit the number of assignable roles. The RBAC roles used in this project are:

- 7f951dda-4ed3-4680-a7ca-43fe172d538d (AcrPull)
- b86a8fe4-44ce-4948-aee5-eccb2c155cd7 (Key Vault Secrets Officer)
- 4633458b-17de-408a-b874-0445c86b69e6 (Key Vault Secrets User)

## Github personal access token
The container registry build task requires a Github PAT. Fine grained can be used. I've used a token with the following repository permissions:

- Read access to actions, administration, code, commit statuses, deployments, and metadata 
- Read and Write access to repository hooks