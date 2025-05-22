variable "prefix" {
  description = "The prefix for all resources"
  type        = string
  default     = "aztpm-avs-rperez"
}


variable "location" {
  description = "The Azure region to deploy resources"
  type        = string
  default     = "East US2"
}

variable "vnetaddressspace" {
  description = "The address space for the virtual network"
  type        = string
  default     = "10.50.0.0/24"
} 
variable "gatewaysubnet" {
  description = "The address space for the Gateway Subnet"
  type        = string
  default     = "10.50.0.0/26"
}
variable "azurebastionsubnet" {
  description = "The address space for the Azure Bastion Subnet"
  type        = string
  default     = "10.50.0.64/26"
}
variable "workloadsubnet" {
  description = "The address space for the Workload Subnet"
  type        = string
  default     = "10.50.0.128/26"
}

variable "avs-sku" {
  description = "The SKU for the Azure VMware Solution"
  type        = string
  default     = "AV36p"
}

variable "avs-hostcount" {
  description = "AVS MGMT cluster size" // minimum of 3 maximum of 16
  type        = string
  default     = 3
}

variable "avs-networkblock" {
  description = "The network block for the Azure VMware Solution"
  type        = string
  default     = "10.100.0.0/22"
}

variable "vmsku" {
  description = "The size of the Windows VM"
  type        = string
  default     = "Standard_DS2_v2"
}



variable "admin_username" {
  description = "The admin username for the Windows VM"
  type        = string
  default     = "avsadmin"
}

variable "admin_password" {
  description = "The admin password for the Windows VM"
  type        = string
  sensitive   = true
  default     = "SuperSecret"
}
