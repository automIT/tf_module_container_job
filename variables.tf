variable "cj_name" {
  description = "Name des Container App Jobs (nur Kleinbuchstaben, Ziffern und '-', max. 32 Zeichen)"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,30}[a-z0-9]$", var.cj_name))
    error_message = "cj_name darf nur Kleinbuchstaben, Ziffern und '-' enthalten, muss mit einem Buchstaben beginnen und hoechstens 32 Zeichen lang sein."
  }
}

variable "resource_group_name" {
  description = "Resourcegruppe, in der Job und Managed Identity angelegt werden. Der Storage Account muss ebenfalls in dieser Resourcegruppe liegen."
  type        = string
}

variable "location" {
  description = "Azure Region. Standard: Region der Resourcegruppe"
  type        = string
  default     = null
}

variable "container_app_environment_id" {
  description = "ID des Container App Environments, in dem der Job laeuft"
  type        = string
}

variable "key_vault_id" {
  description = "Optional: ID des Key Vaults (RBAC-Modus), auf den der Job lesend zugreifen darf"
  type        = string
  default     = null
}

variable "storage_account_name" {
  description = "Optional: Name des Storage Accounts, auf den der Job Blob-Zugriff erhaelt"
  type        = string
  default     = null
}

variable "container_image" {
  description = "Container Image, z.B. mcr.microsoft.com/azuredocs/aci-helloworld:latest"
  type        = string
}

variable "container_name" {
  description = "Name des Containers innerhalb des Jobs"
  type        = string
  default     = "main"
}

variable "cpu" {
  description = "CPU-Kerne pro Replica"
  type        = number
  default     = 0.25
}

variable "memory" {
  description = "Arbeitsspeicher pro Replica (muss zur CPU passen, z.B. 0.25 -> 0.5Gi)"
  type        = string
  default     = "0.5Gi"
}

variable "command" {
  description = "Optional: ueberschreibt den Entrypoint des Images"
  type        = list(string)
  default     = null
}

variable "args" {
  description = "Optional: Argumente fuer den Entrypoint"
  type        = list(string)
  default     = null
}

variable "trigger_type" {
  description = "Art des Triggers: Manual oder Schedule"
  type        = string
  default     = "Manual"

  validation {
    condition     = contains(["Manual", "Schedule"], var.trigger_type)
    error_message = "trigger_type muss \"Manual\" oder \"Schedule\" sein."
  }
}

variable "schedule_trigger_config" {
  description = "Konfiguration fuer trigger_type = Schedule"
  type = object({
    cron_expression          = string
    parallelism              = optional(number, 1)
    replica_completion_count = optional(number, 1)
  })
  default = null
}

variable "manual_trigger_config" {
  description = "Konfiguration fuer trigger_type = Manual"
  type = object({
    parallelism              = optional(number, 1)
    replica_completion_count = optional(number, 1)
  })
  default = {}
}

variable "replica_timeout_in_seconds" {
  description = "Maximale Laufzeit einer Replica in Sekunden"
  type        = number
  default     = 300
}

variable "replica_retry_limit" {
  description = "Anzahl Wiederholungen bei fehlgeschlagener Replica"
  type        = number
  default     = 0
}

variable "env_vars" {
  description = "Zusaetzliche Umgebungsvariablen. Entweder value oder secret_name (Name aus key_vault_secrets) setzen. AZURE_CLIENT_ID, KEY_VAULT_URI und STORAGE_ACCOUNT_NAME setzt das Modul selbst."
  type = list(object({
    name        = string
    value       = optional(string)
    secret_name = optional(string)
  }))
  default = []
}

variable "key_vault_secrets" {
  description = "Secrets aus dem Key Vault, die im Job als Secret verfuegbar gemacht werden. name = Secret-Name im Job, key_vault_secret_name = Name im Key Vault"
  type = list(object({
    name                  = string
    key_vault_secret_name = string
  }))
  default = []
}

variable "probes" {
  description = "Health Probes. type ist Liveness, Readiness oder Startup. initial_delay wird nur bei Liveness verwendet"
  type = list(object({
    type                    = string
    transport               = optional(string, "HTTP")
    port                    = number
    path                    = optional(string)
    initial_delay           = optional(number)
    interval_seconds        = optional(number)
    timeout                 = optional(number)
    failure_count_threshold = optional(number)
  }))
  default = []

  validation {
    condition     = alltrue([for p in var.probes : contains(["Liveness", "Readiness", "Startup"], p.type)])
    error_message = "probes[*].type muss \"Liveness\", \"Readiness\" oder \"Startup\" sein."
  }
}

variable "create_role_assignments" {
  description = "Rollen fuer die Managed Identity auf Key Vault und Storage Account vergeben (benoetigt Berechtigung fuer Role Assignments)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags fuer alle Ressourcen des Moduls"
  type        = map(string)
  default     = {}
}
