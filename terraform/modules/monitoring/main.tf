terraform {
  required_version = ">= 1.5.0"
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "talend_logs" {
  name                = "log-talend-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "log-talend-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Action Group for Alerts (optional, if email is provided)
resource "azurerm_monitor_action_group" "talend_alerts" {
  count               = var.alert_email != "" ? 1 : 0
  name                = "ag-talend-${var.environment}"
  resource_group_name = var.resource_group_name
  short_name          = "talend"

  email_receiver {
    name          = "alert-email"
    email_address = var.alert_email
  }

  tags = merge(
    var.tags,
    {
      Name        = "ag-talend-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Metric Alert: High CPU Usage
resource "azurerm_monitor_metric_alert" "high_cpu" {
  count               = var.alert_email != "" ? 1 : 0
  name                = "alert-talend-high-cpu-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.vm_id]
  description         = "Alert when CPU usage exceeds 90% for 5 minutes"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }

  action {
    action_group_id = azurerm_monitor_action_group.talend_alerts[0].id
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Metric Alert: High Memory Usage
resource "azurerm_monitor_metric_alert" "high_memory" {
  count               = var.alert_email != "" ? 1 : 0
  name                = "alert-talend-high-memory-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.vm_id]
  description         = "Alert when available memory is less than 5%"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1073741824  # 1GB in bytes
  }

  action {
    action_group_id = azurerm_monitor_action_group.talend_alerts[0].id
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Metric Alert: High Disk Usage (OS Disk)
resource "azurerm_monitor_metric_alert" "high_disk" {
  count               = var.alert_email != "" ? 1 : 0
  name                = "alert-talend-high-disk-${var.environment}"
  resource_group_name = var.resource_group_name
  scopes              = [var.vm_id]
  description         = "Alert when disk usage exceeds 85%"
  severity            = 3
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "OS Disk Used Percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = azurerm_monitor_action_group.talend_alerts[0].id
  }

  tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}
