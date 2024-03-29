variable "subscription_id" {
  type        = string
  description = "ID of the subscription to deploy in."
}

variable "tenant_id" {
  type        = string
  description = "ID of the tenant to deploy in."
}

variable "client_id" {
  type        = string
  description = "ID of the service principal used to deploy with. Used for deployment."
}

variable "principal_id" {
  type = string
  description = "Principal ID of the service principal used to deploy with. Used for role assignments."
}

variable "client_secret" {
  sensitive   = true
  type        = string
  description = "Secret of the service principal used to deploy with."
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to deploy in. Must be an existing resource group."
}

variable "github_pat" {
  sensitive = true
  type = string
  description = "Personal Access Token for GitHub. Used to run container registry tasks."
}

variable "kube_cluster_name" {
  type = string
  description = "Name of the Kubernetes cluster to deploy"
  default = "aks-example-1"
}