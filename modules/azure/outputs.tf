output "kubernetes_cluster_admin_config" {
  sensitive = true
  value = azurerm_kubernetes_cluster.main.kube_admin_config.0
}

output "secrets_provider_client_id" {
  description = "Client ID of the secrets provider that was deployed for the Kubernetes cluster."
  value = azurerm_kubernetes_cluster.main.key_vault_secrets_provider.0.secret_identity.0.client_id
}

output "mounted_key_vault_name" {
  value = azurerm_key_vault.aks-mounted.name
  description = "Name of the Azure Key Vault to mount to the Kubernetes cluster."
}

output "secret_names" {
  description = "List of names of secrets to mount to the Kubernetes cluster."
  value = [azurerm_key_vault_secret.test-secret.name, azurerm_key_vault_secret.test-another-secret.name]
}

output "container_registry_login_server" {
  description = "Azure Container Registry login server."
  value = azurerm_container_registry.main.login_server
}

output "container_registry_username" {
  description = "Username for Azure Container Registry."
  value = azurerm_container_registry_scope_map.main.name
}

output "container_registry_password" {
  sensitive = true
  description = "Password for Azure Container Registry."
  value = azurerm_container_registry_token_password.primary.password1.0.value
}
