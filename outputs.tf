output "kubelet_identity" {
  value = azurerm_kubernetes_cluster.main.identity[0]
}

output "identities" {
  value = azurerm_kubernetes_cluster.main.identity[0]
}

output "client_certificate" {
  value     = azurerm_kubernetes_cluster.main.kube_config.0.client_certificate
  sensitive = true
}

output "kube_config" {
  value = azurerm_kubernetes_cluster.main.kube_config_raw

  sensitive = true
}
