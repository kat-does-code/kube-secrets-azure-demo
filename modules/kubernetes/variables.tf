variable "docker_image_name" {
  type = string
  description = "Name of the docker image to deploy to the cluster."
}

variable "kube_cluster_name" {
  type = string
  description = "Name of the Kubernetes cluster to deploy."
}

variable "tenant_id" {
  type        = string
  description = "ID of the tenant to deploy in."
}

variable "kubernetes_cluster_admin_config" {
  type = object({
    host = string
    client_certificate = string
    client_key = string
    username = string
    password = string
    cluster_ca_certificate = string
  })
  description = "Terraform object containing credentials for the Kubernetes cluster."
}

variable "secrets_provider_client_id" {
  type = string
  description = "Client ID of the secrets provider that was deployed for the Kubernetes cluster."
}

variable "mounted_key_vault_name" {
  type = string
  description = "Name of the Azure Key Vault to mount to the Kubernetes cluster."
}

variable "secret_names" {
  type = list(string)
  description = "List of names of secrets to mount to the Kubernetes cluster."
}

variable "container_registry_login_server" {
  type = string
  description = "Azure Container Registry login server."
}

variable "container_registry_username" {
  type = string
  description = "Username for Azure Container Registry."
}

variable "container_registry_password" {
  sensitive = true
  type = string
  description = "Password for Azure Container Registry."
}

variable "deployment_app_name" {
  type = string
  description = "Nickname for the Kubernetes container deployment."
}
