terraform {
  required_version = ">= 1.5.0"
}

# Network Interface
resource "azurerm_network_interface" "talend_nic" {
  name                = "nic-talend-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip_id
  }

  tags = merge(
    var.tags,
    {
      Name        = "nic-talend-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Read SSH public key
data "local_file" "ssh_public_key" {
  filename = var.admin_ssh_key_path
}

# Render cloud-init template
data "template_file" "cloud_init" {
  template = file("${path.module}/cloud-init.tpl")

  vars = {
    admin_username = var.admin_username
  }
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "talend_vm" {
  name                  = "vm-talend-${var.environment}"
  resource_group_name   = var.resource_group_name
  location              = var.location
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.talend_nic.id]

  # Disable password authentication
  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = data.local_file.ssh_public_key.content
  }

  os_disk {
    name                 = "osdisk-talend-${var.environment}"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Cloud-init configuration
  custom_data = base64encode(data.template_file.cloud_init.rendered)

  # Encryption at host (requires feature registration)
  encryption_at_host_enabled = false

  # Boot diagnostics
  boot_diagnostics {
    storage_account_uri = null
  }

  tags = merge(
    var.tags,
    {
      Name        = "vm-talend-${var.environment}"
      Environment = var.environment
      Purpose     = "Talend Remote Engine Benchmark"
      ManagedBy   = "Terraform"
    }
  )
}

# Managed Data Disk
resource "azurerm_managed_disk" "talend_data_disk" {
  name                 = "datadisk-talend-${var.environment}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb

  tags = merge(
    var.tags,
    {
      Name        = "datadisk-talend-${var.environment}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Attach Data Disk to VM
resource "azurerm_virtual_machine_data_disk_attachment" "talend_data_disk_attach" {
  managed_disk_id    = azurerm_managed_disk.talend_data_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.talend_vm.id
  lun                = 0
  caching            = "ReadWrite"
}
