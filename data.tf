data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "storage_account" {
  count = var.storage_account_name != null ? 1 : 0

  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

# Key Vault wird ueber die ID uebergeben, Name und Resourcegruppe stecken in der ID:
# /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<name>
data "azurerm_key_vault" "key_vault" {
  count = var.key_vault_id != null ? 1 : 0

  name                = element(split("/", var.key_vault_id), 8)
  resource_group_name = element(split("/", var.key_vault_id), 4)
}

# Feste Trainings-Registry: Die Identity <resource_group_name>-uami legt der Trainer
# vorab an (tf-container_apps/infra) und berechtigt sie mit AcrPull auf der Registry.
locals {
  registry_server        = "automittraincapp.azurecr.io"
  registry_identity_name = "${var.resource_group_name}-uami"
}

data "azurerm_user_assigned_identity" "acr_pull" {
  name                = local.registry_identity_name
  resource_group_name = var.resource_group_name
}
