locals {
  # Diese Umgebungsvariablen setzt das Modul immer, damit der Job
  # Key Vault und Storage Account per Managed Identity finden kann
  default_env_vars = concat(
    [{ name = "AZURE_CLIENT_ID", value = azurerm_user_assigned_identity.identity.client_id, secret_name = null }],
    [for kv in data.azurerm_key_vault.key_vault : { name = "KEY_VAULT_URI", value = kv.vault_uri, secret_name = null }],
    [for st in data.azurerm_storage_account.storage_account : { name = "STORAGE_ACCOUNT_NAME", value = st.name, secret_name = null }],
  )
}

resource "azurerm_user_assigned_identity" "identity" {
  name                = "id-${var.cj_name}"
  location            = coalesce(var.location, data.azurerm_resource_group.rg.location)
  resource_group_name = data.azurerm_resource_group.rg.name
  tags                = var.tags
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  count = var.create_role_assignments && var.key_vault_id != null ? 1 : 0

  scope                            = var.key_vault_id
  role_definition_name             = "Key Vault Secrets User"
  principal_id                     = azurerm_user_assigned_identity.identity.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  count = var.create_role_assignments && var.storage_account_name != null ? 1 : 0

  scope                            = data.azurerm_storage_account.storage_account[0].id
  role_definition_name             = "Storage Blob Data Contributor"
  principal_id                     = azurerm_user_assigned_identity.identity.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

resource "azurerm_container_app_job" "job" {
  name                         = var.cj_name
  location                     = coalesce(var.location, data.azurerm_resource_group.rg.location)
  resource_group_name          = data.azurerm_resource_group.rg.name
  container_app_environment_id = var.container_app_environment_id
  replica_timeout_in_seconds   = var.replica_timeout_in_seconds
  replica_retry_limit          = var.replica_retry_limit
  tags                         = var.tags

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.identity.id,
      data.azurerm_user_assigned_identity.acr_pull.id,
    ]
  }

  # Image-Pull aus der Trainings-Registry, die Identity hat bereits AcrPull
  registry {
    server   = local.registry_server
    identity = data.azurerm_user_assigned_identity.acr_pull.id
  }

  dynamic "manual_trigger_config" {
    for_each = var.trigger_type == "Manual" ? [var.manual_trigger_config] : []
    content {
      parallelism              = manual_trigger_config.value.parallelism
      replica_completion_count = manual_trigger_config.value.replica_completion_count
    }
  }

  dynamic "schedule_trigger_config" {
    for_each = var.trigger_type == "Schedule" ? [var.schedule_trigger_config] : []
    content {
      cron_expression          = schedule_trigger_config.value.cron_expression
      parallelism              = schedule_trigger_config.value.parallelism
      replica_completion_count = schedule_trigger_config.value.replica_completion_count
    }
  }

  # Secrets werden nicht im Klartext uebergeben, sondern aus dem Key Vault referenziert
  dynamic "secret" {
    for_each = var.key_vault_secrets
    content {
      name                = secret.value.name
      key_vault_secret_id = "${data.azurerm_key_vault.key_vault[0].vault_uri}secrets/${secret.value.key_vault_secret_name}"
      identity            = azurerm_user_assigned_identity.identity.id
    }
  }

  template {
    container {
      name    = var.container_name
      image   = "${local.registry_server}/${var.container_image}"
      cpu     = var.cpu
      memory  = var.memory
      command = var.command
      args    = var.args

      dynamic "env" {
        for_each = concat(local.default_env_vars, var.env_vars)
        content {
          name        = env.value.name
          value       = env.value.value
          secret_name = env.value.secret_name
        }
      }

      dynamic "liveness_probe" {
        for_each = [for p in var.probes : p if p.type == "Liveness"]
        content {
          transport               = liveness_probe.value.transport
          port                    = liveness_probe.value.port
          path                    = liveness_probe.value.path
          initial_delay           = liveness_probe.value.initial_delay
          interval_seconds        = liveness_probe.value.interval_seconds
          timeout                 = liveness_probe.value.timeout
          failure_count_threshold = liveness_probe.value.failure_count_threshold
        }
      }

      dynamic "readiness_probe" {
        for_each = [for p in var.probes : p if p.type == "Readiness"]
        content {
          transport               = readiness_probe.value.transport
          port                    = readiness_probe.value.port
          path                    = readiness_probe.value.path
          interval_seconds        = readiness_probe.value.interval_seconds
          timeout                 = readiness_probe.value.timeout
          failure_count_threshold = readiness_probe.value.failure_count_threshold
        }
      }

      dynamic "startup_probe" {
        for_each = [for p in var.probes : p if p.type == "Startup"]
        content {
          transport               = startup_probe.value.transport
          port                    = startup_probe.value.port
          path                    = startup_probe.value.path
          interval_seconds        = startup_probe.value.interval_seconds
          timeout                 = startup_probe.value.timeout
          failure_count_threshold = startup_probe.value.failure_count_threshold
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.trigger_type != "Schedule" || var.schedule_trigger_config != null
      error_message = "Bei trigger_type = \"Schedule\" muss schedule_trigger_config gesetzt sein."
    }
    precondition {
      condition     = length(var.key_vault_secrets) == 0 || var.key_vault_id != null
      error_message = "key_vault_secrets benoetigt key_vault_id."
    }
  }

  # Die Identity muss Zugriff auf den Key Vault haben, bevor Secrets aufgeloest werden
  depends_on = [
    azurerm_role_assignment.key_vault_secrets_user,
    azurerm_role_assignment.storage_blob_data_contributor,
  ]
}
