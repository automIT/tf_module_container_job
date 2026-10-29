output "id" {
  description = "ID des Container App Jobs"
  value       = azurerm_container_app_job.job.id
}

output "name" {
  description = "Name des Container App Jobs"
  value       = azurerm_container_app_job.job.name
}

output "identity_principal_id" {
  description = "Principal ID der Managed Identity des Jobs"
  value       = azurerm_user_assigned_identity.identity.principal_id
}

output "identity_client_id" {
  description = "Client ID der Managed Identity des Jobs"
  value       = azurerm_user_assigned_identity.identity.client_id
}
