terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "~> 2.2"
    }
  }

  # Uncomment to use Azure Storage backend for state management
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstate"
  #   container_name       = "tfstate"
  #   key                  = "talend-benchmark-dev.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
  }
}

# Network Module
module "network" {
  source = "../../modules/network"

  resource_group_name     = var.resource_group_name
  location                = var.location
  environment             = var.environment
  allowed_ssh_source_ips  = var.allowed_ssh_source_ips
  tags                    = var.tags
}

# VM Module
module "vm" {
  source = "../../modules/vm"

  resource_group_name  = var.resource_group_name
  location             = var.location
  environment          = var.environment
  subnet_id            = module.network.subnet_id
  public_ip_id         = module.network.public_ip_id
  vm_size              = var.vm_size
  admin_ssh_key_path   = pathexpand(var.admin_ssh_key_path)
  tags                 = var.tags
}

# Storage Module
module "storage" {
  source = "../../modules/storage"

  resource_group_name = var.resource_group_name
  location            = var.location
  environment         = var.environment
  tags                = var.tags
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = var.resource_group_name
  location            = var.location
  environment         = var.environment
  vm_id               = module.vm.vm_id
  alert_email         = var.alert_email
  tags                = var.tags
}
