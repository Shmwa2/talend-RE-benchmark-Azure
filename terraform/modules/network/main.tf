terraform {
  required_version = ">= 1.5.0"
}

# Virtual Network
resource "azurerm_virtual_network" "talend_vnet" {
  name                = "vnet-talend-${var.environment}"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Name        = "vnet-talend-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Subnet for Talend Remote Engine
resource "azurerm_subnet" "talend_subnet" {
  name                 = "snet-talend-${var.environment}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.talend_vnet.name
  address_prefixes     = [var.subnet_address_prefix]
}

# Network Security Group
resource "azurerm_network_security_group" "talend_nsg" {
  name                = "nsg-talend-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = merge(
    var.tags,
    {
      Name        = "nsg-talend-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# NSG Rule: Allow SSH (Inbound)
resource "azurerm_network_security_rule" "allow_ssh" {
  name                        = "AllowSSH"
  priority                    = 1000
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = length(var.allowed_ssh_source_ips) == 1 && var.allowed_ssh_source_ips[0] == "*" ? "0.0.0.0/0" : null
  source_address_prefixes     = length(var.allowed_ssh_source_ips) == 1 && var.allowed_ssh_source_ips[0] == "*" ? null : var.allowed_ssh_source_ips
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.talend_nsg.name
}

# NSG Rule: Allow HTTPS Outbound (for Talend Cloud connectivity)
resource "azurerm_network_security_rule" "allow_https_outbound" {
  name                        = "AllowHTTPSOutbound"
  priority                    = 1010
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.talend_nsg.name
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "talend_nsg_assoc" {
  subnet_id                 = azurerm_subnet.talend_subnet.id
  network_security_group_id = azurerm_network_security_group.talend_nsg.id
}

# Public IP for VM (optional, for management)
resource "azurerm_public_ip" "talend_public_ip" {
  name                = "pip-talend-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = merge(
    var.tags,
    {
      Name        = "pip-talend-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}
