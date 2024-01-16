// ---------------------
// Kubernetes deployment
// ---------------------

resource "kubernetes_manifest" "secrets_provider_class_keyvault" {
  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"
    metadata = {
      name      = "akv-mount-aks-msi"
      namespace = "default"
    }
    spec = {
      provider = "azure"
      parameters = {
        usePodIdentity         = "false"
        useVMManagedIdentity   = "true"                         # Set to true for using managed identity
        userAssignedIdentityID = var.secrets_provider_client_id # Set the clientID of the user-assigned managed identity to use
        keyvaultName           = var.mounted_key_vault_name     # Set to the name of your key vault
        cloudName              = ""                             # [OPTIONAL for Azure] if not provided, the Azure environment defaults to AzurePublicCloud
        objects                = <<EOT
          array:
          %{for name in var.secret_names}
            - |
              objectName: ${name}
              objectType: "secret" # object types: secret, key, or cert
          %{endfor}
            EOT

        tenantId = var.tenant_id # The tenant ID of the key vault
      }
    }
  }
}

resource "kubernetes_secret" "image_pull_secret" {
  metadata {
    name      = "acr-pull-secret"
    namespace = "default"
  }
  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${var.container_registry_login_server}" = {   // azurerm_container_registry.main.login_server
          "username" = var.container_registry_username // azurerm_container_registry.main.name,
          "password" = var.container_registry_password // azurerm_container_registry_token_password.primary.password1.0.value
          "email"    = null
          "auth"     = base64encode("${var.container_registry_username}:${var.container_registry_password}")
        }
      }
    })
  }
}

resource "kubernetes_deployment" "deploy" {
  provider   = kubernetes
  depends_on = [kubernetes_manifest.secrets_provider_class_keyvault]
  metadata {
    name      = "${var.deployment_app_name}-deploy"
    namespace = "default"
  }
  spec {
    selector {
      match_labels = {
        "app" = var.deployment_app_name
      }
    }
    template {
      metadata {
        name      = var.deployment_app_name
        namespace = "default"
        labels    = { "app" = var.deployment_app_name }
      }
      spec {
        image_pull_secrets {
          name = kubernetes_secret.image_pull_secret.metadata.0.name
        }
        container {
          image   = "${var.container_registry_login_server}/${var.docker_image_name}:latest"
          name    = var.deployment_app_name
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
              command = ["ls", "/mnt/secrets-store/"]
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
  }

  timeouts {
    create = "2m"
  }
}
