output "vm_id" {
  description = "ID of the Virtual Machine"
  value       = azurerm_linux_virtual_machine.talend_vm.id
}

output "vm_name" {
  description = "Name of the Virtual Machine"
  value       = azurerm_linux_virtual_machine.talend_vm.name
}

output "vm_private_ip" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.talend_nic.private_ip_address
}

output "vm_admin_username" {
  description = "Admin username for the VM"
  value       = var.admin_username
}

output "data_disk_id" {
  description = "ID of the data disk"
  value       = azurerm_managed_disk.talend_data_disk.id
}

output "nic_id" {
  description = "ID of the Network Interface"
  value       = azurerm_network_interface.talend_nic.id
}
