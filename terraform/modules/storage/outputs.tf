output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = azurerm_storage_account.talend_storage.id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = azurerm_storage_account.talend_storage.name
}

output "storage_primary_connection_string" {
  description = "Primary connection string for the Storage Account"
  value       = azurerm_storage_account.talend_storage.primary_connection_string
  sensitive   = true
}

output "storage_primary_blob_endpoint" {
  description = "Primary blob endpoint"
  value       = azurerm_storage_account.talend_storage.primary_blob_endpoint
}

output "benchmark_results_container_name" {
  description = "Name of the benchmark results container"
  value       = azurerm_storage_container.benchmark_results.name
}

output "logs_container_name" {
  description = "Name of the logs container"
  value       = azurerm_storage_container.logs.name
}

output "test_data_container_name" {
  description = "Name of the test data container"
  value       = azurerm_storage_container.test_data.name
}
