variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "japaneast"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vm_size" {
  description = "Size of the Virtual Machine"
  type        = string
  default     = "Standard_D8s_v5"
}

variable "admin_ssh_key_path" {
  description = "Path to the SSH public key file"
  type        = string
  default     = "~/.ssh/talend-azure-key.pub"
}

variable "allowed_ssh_source_ips" {
  description = "List of IP addresses allowed to SSH to the VM"
  type        = list(string)
  default     = ["*"]  # CHANGE THIS to your IP address for production
}

variable "alert_email" {
  description = "Email address for alert notifications (leave empty to disable alerts)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "Talend Benchmark"
    ManagedBy = "Terraform"
  }
}
