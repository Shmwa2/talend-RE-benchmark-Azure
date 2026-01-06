output "vm_public_ip" {
  description = "Public IP address of the Talend VM"
  value       = module.network.public_ip_address
}

output "vm_private_ip" {
  description = "Private IP address of the Talend VM"
  value       = module.vm.vm_private_ip
}

output "vm_name" {
  description = "Name of the Talend VM"
  value       = module.vm.vm_name
}

output "vm_id" {
  description = "Resource ID of the Talend VM"
  value       = module.vm.vm_id
}

output "ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh -i ~/.ssh/talend-azure-key ${module.vm.vm_admin_username}@${module.network.public_ip_address}"
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = module.storage.storage_account_name
}

output "storage_blob_endpoint" {
  description = "Blob endpoint of the Storage Account"
  value       = module.storage.storage_primary_blob_endpoint
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = module.monitoring.log_analytics_workspace_name
}

output "resource_group_name" {
  description = "Name of the Resource Group"
  value       = var.resource_group_name
}
