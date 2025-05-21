terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}

}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  address_space       = [var.vnetaddressspace]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags = {
    environment = "lab"
  }
}

resource "azurerm_subnet" "azuregateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.gatewaysubnet]
}

resource "azurerm_subnet" "azurebastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.azurebastionsubnet]
}

resource "azurerm_subnet" "workload" {
  name                 = "Workload"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.workloadsubnet] 
}

resource "azurerm_network_interface" "main" {
  name                = "${var.prefix}nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "main" {
  name                = "aztpm-avs-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = var.vmsku
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-avsadmin"
  }
  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter"
    version   = "latest"
  }
  tags = {
    environment = "lab"
  }
}

resource "azurerm_virtual_network_gateway" "expressroute" {
  name                = "${var.prefix}-vngw"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  type = "ExpressRoute"
  sku  = "ErGw1AZ"

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vngw.id
    subnet_id                     = azurerm_subnet.azuregateway.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.azuregateway]
}

resource "azurerm_public_ip" "vngw" {
  name                = "${var.prefix}vngw-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "bastion" {
  name                = "${var.prefix}-bastion-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "main" {
  name                = "${var.prefix}-bastion"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku = "Standard"

  ip_configuration {
    name                 = "bastion-ip-config"
    subnet_id            = azurerm_subnet.azurebastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tunneling_enabled  = true // Enables native client support
  copy_paste_enabled = true // Enables copy-paste
  file_copy_enabled  = true // Enables file copy (optional, best practice)
  scale_units        = 2    // Best practice: minimum 2 for production, adjust as needed

  depends_on = [azurerm_subnet.azurebastion]
}

resource "azurerm_vmware_private_cloud" "main" {
  name                = "${var.prefix}-avs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = var.avs-sku

  management_cluster {
    size = var.avs-hostcount
  }
  network_subnet_cidr         = var.avs-networkblock
  internet_connection_enabled = false

  timeouts {
    create = "10h"
  }
  
  tags = {
    environment = "lab"
  }
}

resource "azurerm_vmware_express_route_authorization" "main" {
  name             = "avs-expressroute-auth"
  private_cloud_id = azurerm_vmware_private_cloud.main.id
}

resource "azurerm_virtual_network_gateway_connection" "main" {
  name                = "avs-expressroute-connection"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  type                       = "ExpressRoute"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.expressroute.id
  express_route_circuit_id   = azurerm_vmware_private_cloud.main.circuit[0].express_route_id
  authorization_key          = azurerm_vmware_express_route_authorization.main.express_route_authorization_key


  depends_on = [
    azurerm_vmware_private_cloud.main,
    azurerm_virtual_network_gateway.expressroute,
    azurerm_vmware_express_route_authorization.main
  ]
}
