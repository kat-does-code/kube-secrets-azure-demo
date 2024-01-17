terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.87.0"
    }

    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.25.2"
    }
  }
}

provider "kubernetes" {
  experiments {
    manifest_resource = true
  }
  host                   = var.kubernetes_cluster_admin_config.host
  client_key             = base64decode(var.kubernetes_cluster_admin_config.client_key)
  client_certificate     = base64decode(var.kubernetes_cluster_admin_config.client_certificate)
  cluster_ca_certificate = base64decode(var.kubernetes_cluster_admin_config.cluster_ca_certificate)
  username               = var.kubernetes_cluster_admin_config.username
  password               = var.kubernetes_cluster_admin_config.password
}