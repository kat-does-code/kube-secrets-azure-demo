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
    
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  client_id     = var.client_id
  client_secret = var.client_secret

  skip_provider_registration = true
}
