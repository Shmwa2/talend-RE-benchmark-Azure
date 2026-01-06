output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.talend_logs.id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.talend_logs.name
}

output "log_analytics_workspace_key" {
  description = "Primary shared key for Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.talend_logs.primary_shared_key
  sensitive   = true
}

output "action_group_id" {
  description = "ID of the Action Group (if created)"
  value       = var.alert_email != "" ? azurerm_monitor_action_group.talend_alerts[0].id : null
}
