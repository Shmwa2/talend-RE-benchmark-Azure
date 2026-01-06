terraform {
  required_version = ">= 1.5.0"
}

# Generate random string for unique storage account name
resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Storage Account for benchmark results and logs
resource "azurerm_storage_account" "talend_storage" {
  name                     = "sttalend${var.environment}${random_string.storage_suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  min_tls_version          = "TLS1_2"

  # Enable encryption
  enable_https_traffic_only = true

  # Blob properties
  blob_properties {
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "sttalend${var.environment}"
      Environment = var.environment
      Purpose     = "Benchmark Results and Logs"
      ManagedBy   = "Terraform"
    }
  )
}

# Blob Container for benchmark results
resource "azurerm_storage_container" "benchmark_results" {
  name                  = "benchmark-results"
  storage_account_name  = azurerm_storage_account.talend_storage.name
  container_access_type = "private"
}

# Blob Container for logs
resource "azurerm_storage_container" "logs" {
  name                  = "logs"
  storage_account_name  = azurerm_storage_account.talend_storage.name
  container_access_type = "private"
}

# Blob Container for test data
resource "azurerm_storage_container" "test_data" {
  name                  = "test-data"
  storage_account_name  = azurerm_storage_account.talend_storage.name
  container_access_type = "private"
}

# Blob Container for configurations backup
resource "azurerm_storage_container" "configs" {
  name                  = "configs"
  storage_account_name  = azurerm_storage_account.talend_storage.name
  container_access_type = "private"
}

# Lifecycle policy for automatic cleanup
resource "azurerm_storage_management_policy" "lifecycle_policy" {
  storage_account_id = azurerm_storage_account.talend_storage.id

  rule {
    name    = "delete-old-benchmark-results"
    enabled = true
    filters {
      prefix_match = ["benchmark-results/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 90
      }
    }
  }

  rule {
    name    = "delete-old-logs"
    enabled = true
    filters {
      prefix_match = ["logs/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }
}
