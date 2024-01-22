locals {
  source_code_repository_url = "https://github.com/kat-does-code/kube-secrets-azure-demo"
  source_code_branch         = "main"
  docker_image_name          = "helloworld"
  container_registry_name    = "${lower(substr(replace(data.azurerm_resource_group.example.name, "-", ""), 0, 30))}${random_string.acr_name_postfix.result}" // Generate a unique name related to the resource group name
  vm_size                    = "Standard_D2_v2"

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

// ------------------
// Kubernetes Cluster
// ------------------
resource "azurerm_user_assigned_identity" "kubelet" {
  // Create a single managed identity for Kubelet to use. AKS creates at least three more 
  // identities in a different resource group. For ease of access, we manage our own identity
  // for kubelet.
  name = "id-${var.kube_cluster_name }-kubelet"
  resource_group_name = data.azurerm_resource_group.example.name
  location = data.azurerm_resource_group.example.location
}

resource "azurerm_user_assigned_identity" "control_plane" {
  // Required if bringing your own Kubelet identity. 
  name = "id-${var.kube_cluster_name }-cp"
  resource_group_name = data.azurerm_resource_group.example.name
  location = data.azurerm_resource_group.example.location  
}

resource "azurerm_role_assignment" "control_plane-managed_identity_operator" {
  name                             = uuidv5("url", "${azurerm_user_assigned_identity.control_plane.principal_id}.principal.managed_identity_operator.roleassignment")
  principal_id                     = azurerm_user_assigned_identity.control_plane.principal_id
  role_definition_name             = "Managed Identity Operator"
  scope                            = azurerm_user_assigned_identity.kubelet.id
  skip_service_principal_aad_check = true
}

resource "azurerm_kubernetes_cluster" "main" {
  // Any and all identities used for managing the cluster and its components will be automatically
  // created by Azure. Role based access control is enabled, so we can control each identity's 
  // access to resources. This allows for the seamless integration of container registries and
  // key vaults. For more information on AKS managed identities, refer to the page below:
  // 
  // https://learn.microsoft.com/en-us/azure/aks/use-managed-identity

  name                = var.kube_cluster_name 
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
    type = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.control_plane.id ]
  }

  key_vault_secrets_provider {
    // Creates a key_vault_secrets_provider managed identity
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  kubelet_identity {
    client_id = azurerm_user_assigned_identity.kubelet.client_id
    object_id =  azurerm_user_assigned_identity.kubelet.principal_id
    user_assigned_identity_id =  azurerm_user_assigned_identity.kubelet.id
  }

  api_server_access_profile {
    authorized_ip_ranges = [var.kube_api_server_allowed_ip]
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

// ---------
// Key Vault
// ---------
resource "azurerm_key_vault" "aks-mounted" {
  // This key vault will be mounted to our AKS cluster. We'll mount this using Secrets Store 
  // CSI drivers. The key vault is accessed with a key_vault_secrets_provider managed identity,
  // which is created by AKS. More information can be found on the following page:
  //
  // https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver

  name                      = var.mounted_key_vault_name
  sku_name                  = "standard"
  enable_rbac_authorization = true

  tenant_id           = var.tenant_id
  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name

  tags = local.tags
}

resource "azurerm_key_vault_secret" "test-secret" {
  depends_on = [ azurerm_role_assignment.terraform-secrets_officer ]
  name         = "test-secret"
  value        = "Test secret value with spaces"
  key_vault_id = azurerm_key_vault.aks-mounted.id
}

resource "azurerm_key_vault_secret" "test-another-secret" {
  depends_on = [ azurerm_role_assignment.terraform-secrets_officer ]
  name         = "test-another-secret"
  value        = "Perhaps another secret just to make sure the yaml is correctly formatted."
  key_vault_id = azurerm_key_vault.aks-mounted.id
}

resource "azurerm_role_assignment" "terraform-secrets_officer" {
  // The service principal for terraform is granted access to the specified key vault and can read+write secrets. 
  //
  // https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver

  name                             = uuidv5("url", "${var.principal_id}.principal.secrets_user.roleassignment")
  principal_id                     = var.principal_id
  role_definition_name             = "Key Vault Secrets Officer"
  scope                            = azurerm_key_vault.aks-mounted.id
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "secrets_provider-secret_user" {
  // The service principal for terraform is granted access to the specified key vault and can read+write secrets. 
  //
  // https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver

  name                             = uuidv5("url", "${azurerm_kubernetes_cluster.main.key_vault_secrets_provider.0.secret_identity.0.object_id}.principal.secrets_user.roleassignment")
  principal_id                     = azurerm_kubernetes_cluster.main.key_vault_secrets_provider.0.secret_identity.0.object_id
  role_definition_name             = "Key Vault Secrets User"
  scope                            = azurerm_key_vault.aks-mounted.id
  skip_service_principal_aad_check = true
}

## ------------------
## Container registry 
## ------------------ 
resource "azurerm_container_registry" "main" {
  // This azure container registry will be connected to our AKS cluster.

  name = local.container_registry_name
  sku  = "Basic"

  location            = data.azurerm_resource_group.example.location
  resource_group_name = data.azurerm_resource_group.example.name

  tags = local.tags
}


resource "azurerm_container_registry_task" "build" {
  // We set up a task that ensures docker images are built and pushed to the container registry
  // when a new commit is pushed to Github.
  name                  = "build-test-image"
  container_registry_id = azurerm_container_registry.main.id
  platform {
    os = "Linux"
  }

  source_trigger {
    name           = "build-on-commit"
    repository_url = local.source_code_repository_url
    events         = ["commit"]
    source_type    = "Github"
    branch         = local.source_code_branch
    authentication {
      token      = var.github_pat
      token_type = "PAT"
    }
  }

  docker_step {
    dockerfile_path      = "Dockerfile"
    context_path         = "${local.source_code_repository_url}#${local.source_code_branch}:build"
    context_access_token = var.github_pat
    image_names          = ["${local.docker_image_name}:{{.Run.ID}}", "${local.docker_image_name}:latest"]
  }
}

resource "azurerm_container_registry_scope_map" "main" {
  name                    = "${local.source_code_branch}-scope"
  resource_group_name     = data.azurerm_resource_group.example.name
  container_registry_name = azurerm_container_registry.main.name
  actions = [
    "repositories/${local.docker_image_name}/content/read",
    "repositories/${local.docker_image_name}/metadata/read"
  ]
}

resource "azurerm_container_registry_token" "primary" {
  name                    = "${azurerm_container_registry_scope_map.main.name}-token"
  resource_group_name     = data.azurerm_resource_group.example.name
  scope_map_id            = azurerm_container_registry_scope_map.main.id
  container_registry_name = azurerm_container_registry.main.name
}

resource "time_offset" "password_validity_time" {
  offset_days = 30
}

resource "azurerm_container_registry_token_password" "primary" {
  container_registry_token_id = azurerm_container_registry_token.primary.id
  password1 {
    expiry = time_offset.password_validity_time.rfc3339
  }
}

resource "azurerm_role_assignment" "kubelet-acrpull" {
  // This role assignment 'connects' AKS and ACR. All it does is grant the 'AcrPull' role on the
  // AKS Kubelet identity in Azure. For more information, refer to the page below:
  // 
  // https://learn.microsoft.com/en-us/azure/aks/cluster-container-registry-integration

  name                             = uuidv5("url", "kubelet.principal.acrpull.roleassignment")
  principal_id                     = azurerm_user_assigned_identity.kubelet.principal_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}