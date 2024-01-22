locals {
  docker_image_name = "helloworld"
}

module "azure" {
  source = "./modules/azure"

  docker_image_name = local.docker_image_name

  client_id           = var.client_id
  principal_id        = var.principal_id
  client_secret       = var.client_secret
  tenant_id           = var.tenant_id
  subscription_id     = var.subscription_id
  resource_group_name = var.resource_group_name

  kube_cluster_name          = var.kube_cluster_name

  github_pat = var.github_pat
}

module "kubernetes" {
  source = "./modules/kubernetes"

  kube_cluster_name   = var.kube_cluster_name
  deployment_app_name = "secrets-tester"

  kubernetes_cluster_admin_config = {
    host                   = module.azure.kubernetes_cluster_admin_config.host
    client_certificate     = module.azure.kubernetes_cluster_admin_config.client_certificate
    client_key             = module.azure.kubernetes_cluster_admin_config.client_key
    cluster_ca_certificate = module.azure.kubernetes_cluster_admin_config.cluster_ca_certificate
    username               = module.azure.kubernetes_cluster_admin_config.username
    password               = module.azure.kubernetes_cluster_admin_config.password
  }


  docker_image_name               = local.docker_image_name
  container_registry_login_server = module.azure.container_registry_login_server
  container_registry_password     = module.azure.container_registry_password
  container_registry_username     = module.azure.container_registry_username


  secret_names               = module.azure.secret_names
  mounted_key_vault_name     = module.azure.mounted_key_vault_name
  secrets_provider_client_id = module.azure.secrets_provider_client_id

  tenant_id = var.tenant_id
}
