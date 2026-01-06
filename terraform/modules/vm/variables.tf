variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
  default     = "dev"
}

variable "subnet_id" {
  description = "ID of the subnet where VM will be deployed"
  type        = string
}

variable "public_ip_id" {
  description = "ID of the public IP to associate with VM"
  type        = string
}

variable "vm_size" {
  description = "Size of the Virtual Machine"
  type        = string
  default     = "Standard_D8s_v5"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_key_path" {
  description = "Path to the SSH public key file"
  type        = string
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 128
}

variable "data_disk_size_gb" {
  description = "Size of the data disk in GB"
  type        = number
  default     = 512
}

variable "data_disk_type" {
  description = "Type of the data disk (Premium_LRS, StandardSSD_LRS, etc.)"
  type        = string
  default     = "Premium_LRS"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
