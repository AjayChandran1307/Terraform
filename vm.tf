terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.27.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = "bf6e09fe-e8d6-4494-b2bf-38eab2bc8fed"
  
}
variable "prefix" {
  default = "TerVM"
}

resource "azurerm_resource_group" "TerRG" {
  name     = "${var.prefix}-rg"
  location = "East US"
}

resource "azurerm_virtual_network" "HUBVNET" {
  name                = "${var.prefix}-VNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.TerRG.location
  resource_group_name = azurerm_resource_group.TerRG.name
}
resource "azurerm_network_security_group" "vm_nsg" {
  name                = "vm-nsg"
  location            = azurerm_resource_group.TerRG.location
  resource_group_name = azurerm_resource_group.TerRG.name

  security_rule {
    name                       = "SSH-Allow"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet" "testsubnet" {
  name                 = "subnet1"
  resource_group_name  = azurerm_resource_group.TerRG.name
  virtual_network_name = azurerm_virtual_network.HUBVNET.name
  address_prefixes     = ["10.0.1.0/24"]
  }
  resource "azurerm_subnet_network_security_group_association" "subnet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.testsubnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
}
# Public IP
resource "azurerm_public_ip" "TERPUB" {
  name                = "TERPUBip"
  location            = azurerm_resource_group.TerRG.location
  resource_group_name = azurerm_resource_group.TerRG.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_network_interface" "NIC" {
  name                = "TerVM-nic1"
  location            = "East US"
  resource_group_name = "TerVM-rg"

  ip_configuration {
    name                          = "VMip"
    subnet_id                     = azurerm_subnet.testsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.TERPUB.id
  }
}

resource "azurerm_virtual_machine" "VM" {
  name                  = "${var.prefix}-1"
  location              = azurerm_resource_group.TerRG.location
  resource_group_name   = azurerm_resource_group.TerRG.name
  network_interface_ids = [azurerm_network_interface.NIC.id]
  vm_size               = "Standard_DS1_v2"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  # delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  # delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "Terrvm"
    admin_username = "ajay"
    admin_password = "Welcome@12345"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "Testing"
  }
}