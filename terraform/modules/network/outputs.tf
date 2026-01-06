output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.talend_vnet.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.talend_vnet.name
}

output "subnet_id" {
  description = "ID of the Talend subnet"
  value       = azurerm_subnet.talend_subnet.id
}

output "subnet_name" {
  description = "Name of the Talend subnet"
  value       = azurerm_subnet.talend_subnet.name
}

output "nsg_id" {
  description = "ID of the Network Security Group"
  value       = azurerm_network_security_group.talend_nsg.id
}

output "public_ip_address" {
  description = "Static Public IP address for the VM"
  value       = azurerm_public_ip.talend_public_ip.ip_address
}

output "public_ip_id" {
  description = "ID of the Public IP"
  value       = azurerm_public_ip.talend_public_ip.id
}
