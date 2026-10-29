# Modul: container_job

Legt einen Azure Container App Job inklusive User Assigned Managed Identity an.
Optional erhält die Identity Lesezugriff auf Secrets im Key Vault und Blob-Zugriff auf den Storage Account.

Erzeugte Ressourcen:

- `azurerm_user_assigned_identity` (`id-<cj_name>`)
- `azurerm_role_assignment` "Key Vault Secrets User" auf dem Key Vault (wenn `key_vault_id` gesetzt)
- `azurerm_role_assignment` "Storage Blob Data Contributor" auf dem Storage Account (wenn `storage_account_name` gesetzt)
- `azurerm_container_app_job`

Im Container wird immer `AZURE_CLIENT_ID` gesetzt, je nach Parameter zusätzlich `KEY_VAULT_URI` und `STORAGE_ACCOUNT_NAME`.

## Verwendung

```hcl
module "containerjob_scheduled" {
  source = "git::https://dev.azure.com/automITde/training/_git/tf_module_container_job?ref=1.0.0"

  cj_name                      = "autws15-scheduled"
  resource_group_name          = data.azurerm_resource_group.rg.name
  container_app_environment_id = data.azurerm_container_app_environment.cae.id
  key_vault_id                 = data.azurerm_key_vault.key_vault.id
  storage_account_name         = data.azurerm_storage_account.storage_account.name
  container_image              = "mcr.microsoft.com/azuredocs/aci-helloworld:latest"

  trigger_type = "Schedule"
  schedule_trigger_config = {
    cron_expression          = "*/5 * * * *"
    parallelism              = 1
    replica_completion_count = 1
  }

  env_vars = [
    {
      name  = "test"
      value = "1234"
    }
  ]
}
```

## Inputs

| Name | Typ | Default | Beschreibung |
|------|-----|---------|--------------|
| `cj_name` | string | – | Name des Jobs (Kleinbuchstaben, Ziffern, `-`, max. 32 Zeichen) |
| `resource_group_name` | string | – | Resourcegruppe für Job und Identity, Storage Account muss hier liegen |
| `container_app_environment_id` | string | – | ID des Container App Environments |
| `key_vault_id` | string | `null` | ID des Key Vaults (RBAC-Modus) |
| `storage_account_name` | string | `null` | Name des Storage Accounts (in `resource_group_name`) |
| `container_image` | string | – | Container Image |
| `location` | string | Region der RG | Azure Region |
| `container_name` | string | `"main"` | Name des Containers |
| `cpu` | number | `0.25` | CPU pro Replica |
| `memory` | string | `"0.5Gi"` | Speicher pro Replica |
| `command` | list(string) | `null` | Entrypoint überschreiben |
| `args` | list(string) | `null` | Argumente für den Entrypoint |
| `trigger_type` | string | `"Manual"` | `Manual` oder `Schedule` |
| `schedule_trigger_config` | object | `null` | `cron_expression`, `parallelism`, `replica_completion_count` – Pflicht bei `Schedule` |
| `manual_trigger_config` | object | `{}` | `parallelism`, `replica_completion_count` |
| `replica_timeout_in_seconds` | number | `300` | Maximale Laufzeit einer Replica |
| `replica_retry_limit` | number | `0` | Wiederholungen bei Fehlern |
| `env_vars` | list(object) | `[]` | `name` + `value` oder `secret_name` |
| `key_vault_secrets` | list(object) | `[]` | `name` (im Job) + `key_vault_secret_name` (im Key Vault) |
| `probes` | list(object) | `[]` | `type` (`Liveness`/`Readiness`/`Startup`), `port`, optional `transport`, `path`, `initial_delay`, `interval_seconds`, `timeout`, `failure_count_threshold` (`initial_delay` nur bei `Liveness`) |
| `create_role_assignments` | bool | `true` | Rollen für die Identity vergeben |
| `tags` | map(string) | `{}` | Tags |

## Outputs

| Name | Beschreibung |
|------|--------------|
| `id` | ID des Jobs |
| `name` | Name des Jobs |
| `identity_principal_id` | Principal ID der Managed Identity |
| `identity_client_id` | Client ID der Managed Identity |

## Beispiel: Secret aus dem Key Vault als Umgebungsvariable

```hcl
  key_vault_secrets = [
    {
      name                  = "demo-secret"
      key_vault_secret_name = "demo-secret"
    }
  ]

  env_vars = [
    {
      name        = "DEMO_SECRET"
      secret_name = "demo-secret"
    }
  ]
```
