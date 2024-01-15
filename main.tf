locals {
  container_registry_name = "${substr(trim(data.azurerm_resource_group.example.name, "_()-."), 0, 30)}${random_string.acr_name_postfix.result}" // Generate a unique name related to the resource group name
  vm_size                 = "Standard_D2_v2"

  tags = merge({
    Environment = "Development"
  }, data.azurerm_resource_group.example.tags)
}

data "azurerm_resource_group" "example" {
  name = var.resource_group_name
}

resource "random_string" "acr_name_postfix" {
  length  = 20
  numeric = false
  special = false
  upper   = false
}

// Kubernetes Cluster
resource "azurerm_kubernetes_cluster" "main" {
  // Any and all identities used for managing the cluster and its components will be automatically
  // created by Azure. Role based access control is enabled, so we can control each identity's 
  // access to resources. This allows for the seamless integration of container registries and
  // key vaults. For more information on AKS managed identities, refer to the page below:
  // 
  // https://learn.microsoft.com/en-us/azure/aks/use-managed-identity

  name                = "aks-example-1"
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name
  dns_prefix          = "aks-1"
  node_resource_group = "${data.azurerm_resource_group.example.name}-nodes"

  default_node_pool {
    name       = "systempool"
    node_count = 1
    vm_size    = local.vm_size
  }

  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    managed            = true
    azure_rbac_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  key_management_service {
    key_vault_key_id         = azurerm_key_vault.aks-mounted.id
    key_vault_network_access = "Public"
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  tags = local.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "user-pool" {
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id

  name    = "userpool"
  count   = 1
  vm_size = local.vm_size

  tags = local.tags
}


// Key Vault
resource "azurerm_key_vault" "aks-mounted" {
  // This key vault will be mounted to our AKS cluster. We'll mount this using Secrets Store 
  // CSI drivers. More information can be found on the following page:
  //
  // https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver

  name     = "akv-mount-aks"
  sku_name = "standard"

  tenant_id           = var.tenant_id
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name

  tags = local.tags
}

resource "azurerm_key_vault_secret" "test-secret" {
  name         = "test-secret"
  value        = "Test secret value with spaces"
  key_vault_id = azurerm_key_vault.aks-mounted.id
}

resource "azurerm_key_vault_secret" "test-another-secret" {
  name         = "test-another-secret"
  value        = "Perhaps another secret just to make sure the yaml is correctly formatted."
  key_vault_id = azurerm_key_vault.aks-mounted.id
}

resource "azurerm_role_assignment" "kubelet-secrets_user" {
  // The Azure kubelet identity is granted access to the specified key vault and can read its secrets. 
  //
  // https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver

  name                             = uuidv5("url", "kubelet.principal.secrets_user.roleassignment")
  principal_id                     = azurerm_kubernetes_cluster.main.key_vault_secrets_provider.0.secret_identity.0.object_id
  role_definition_name             = "Key Vault Secrets User"
  scope                            = azurerm_key_vault.aks-mounted.id
  skip_service_principal_aad_check = true
}

// Container registry
resource "azurerm_container_registry" "main" {
  // This azure container registry will be connected to our AKS cluster.

  name = local.container_registry_name
  sku  = "Basic"

  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name

  tags = local.tags
}

resource "azurerm_role_assignment" "kubelet-acrpull" {
  // This role assignment 'connects' AKS and ACR. It works by granting AcrPull role on the 
  // Kubelet identity in Azure. For more information, refer to the page below:
  // 
  // https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration

  name                             = uuidv5("url", "kubelet.principal.acrpull.roleassignment")
  principal_id                     = azurerm_kubernetes_cluster.main.identity[0].principal_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

provider "kubernetes" {
    experiments {
      manifest_resource = true
    }
  host                   = azurerm_kubernetes_cluster.main.kube_admin_config.0.host
  client_key             = azurerm_kubernetes_cluster.main.kube_admin_config.0.client_key
  client_certificate     = azurerm_kubernetes_cluster.main.kube_admin_config.0.client_certificate
  cluster_ca_certificate = azurerm_kubernetes_cluster.main.kube_admin_config.0.cluster_ca_certificate
  username               = azurerm_kubernetes_cluster.main.kube_admin_config.0.username
  password               = azurerm_kubernetes_cluster.main.kube_admin_config.0.password
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.main.kube_admin_config.0.host
  client_key             = azurerm_kubernetes_cluster.main.kube_admin_config.0.client_key
  client_certificate     = azurerm_kubernetes_cluster.main.kube_admin_config.0.client_certificate
  cluster_ca_certificate = azurerm_kubernetes_cluster.main.kube_admin_config.0.cluster_ca_certificate
  username               = azurerm_kubernetes_cluster.main.kube_admin_config.0.username
  password               = azurerm_kubernetes_cluster.main.kube_admin_config.0.password
  
}

resource "kubectl_manifest" "secrets_provider_class_keyvault" {
    provider = kubectl
  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretsProviderClass"
    metadata = {
      name      = "akv-mount-aks-msi"
      namespace = "default"
    }
    spec = {
      provider = "azure"
      parameters = {
        usePodIdentity : "false"
        useVMManagedIdentity : "true"                                                                                                     # Set to true for using managed identity
        userAssignedIdentityID : azurerm_kubernetes_cluster.main.key_vault_secrets_provider.0.secret_identity.0.user_assigned_identity_id # Set the clientID of the user-assigned managed identity to use
        keyvaultName : azurerm_key_vault.aks-mounted.name                                                                                 # Set to the name of your key vault
        cloudName : ""                                                                                                                    # [OPTIONAL for Azure] if not provided, the Azure environment defaults to AzurePublicCloud
        objects = {
          array = [
            {
              objectName = azurerm_key_vault_secret.test-secret.name
              objectType = "secret" # object types: secret, key, or cert
              //objectVersion = "" # [OPTIONAL] object versions, default to latest if empty
            },
            {
              objectName = azurerm_key_vault_secret.test-another-secret.name
              objectType = "secret"
            }
          ]
        }
        tenantId : var.tenant_id # The tenant ID of the key vault
      }
    }
  }
}

resource "kubernetes_pod" "secrets-tester" {
    provider = kubernetes
  depends_on = [ kubectl_manifest.secrets_provider_class_keyvault ]
  metadata {
    name      = "secrets-tester"
    namespace = "default"
  }
  spec {
    container {
      image   = "busybox"
      name    = "busybox"
      command = ["/bin/sh", "-c", "touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600"]
      volume_mount {
        name       = "secrets-store-inline"
        mount_path = "/mnt/secrets-store"
        read_only  = true
      }
      liveness_probe {
        exec {
          command = ["cat", "/tmp/healthy"]
        }
        initial_delay_seconds = 5
        period_seconds        = 5
      }
      readiness_probe {
        exec {
          command = ["cat", "/mnt/secrets-store"]
        }
        initial_delay_seconds = 30
        period_seconds        = 5
      }
    }
    volume {
      name = "secrets-store-inline"
      csi {
        driver    = "secrets-store.csi.k8s.io"
        read_only = true
        volume_attributes = {
          "secretProviderClass" = "akv-mount-aks-msi"
        }
      }
    }
  }
}
