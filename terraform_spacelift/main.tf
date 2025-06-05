terraform {

  required_providers {

    azurerm = {

      source  = "hashicorp/azurerm"

      version = "~> 3.0"

    }

    tls = {

      source  = "hashicorp/tls"

      version = "~> 4.0"

    }

  }

  required_version = ">= 1.1.0"

}

provider "azurerm" {

  features {}

}

# Generate a new RSA SSH key pair

resource "tls_private_key" "demo_key" {

  algorithm = "RSA"

  rsa_bits  = 4096

}


# Optionally: store private key in Azure Key Vault (example)

resource "azurerm_key_vault" "kv" {

  name                        = "kv-demo-${random_integer.suffix.result}"

  location                    = var.location

  resource_group_name         = azurerm_resource_group.main.name

  sku_name                    = "standard"

  tenant_id                   = data.azurerm_client_config.current.tenant_id

  soft_delete_retention_days  = 7

  purge_protection_enabled    = false

}


resource "random_integer" "suffix" {

  min = 10000

  max = 99999

}


resource "azurerm_key_vault_secret" "private_key_secret" {

  name         = "debian-vm-private-key"

  value        = tls_private_key.demo_key.private_key_pem

  key_vault_id = azurerm_key_vault.kv.id

}


# Data source to get tenant ID for Key Vault

data "azurerm_client_config" "current" {}

# Resource Group

resource "azurerm_resource_group" "main" {

  name     = var.resource_group_name

  location = var.location

}


# Virtual Network (VPC)

resource "azurerm_virtual_network" "main" {

  name                = "vnet-example"

  address_space       = ["10.0.0.0/16"]

  location            = azurerm_resource_group.main.location

  resource_group_name = azurerm_resource_group.main.name

}


# Subnet - public

resource "azurerm_subnet" "public" {

  name                 = "subnet-public"

  resource_group_name  = azurerm_resource_group.main.name

  virtual_network_name = azurerm_virtual_network.main.name

  address_prefixes     = ["10.0.1.0/24"]

}


# Public IP for the VM

resource "azurerm_public_ip" "vm" {

  name                = "public-ip-vm"

  location            = azurerm_resource_group.main.location

  resource_group_name = azurerm_resource_group.main.name

  allocation_method   = "Static"

  sku                 = "Standard"

}


# Network Security Group with inbound port 22 and 80 open

resource "azurerm_network_security_group" "main" {

  name                = "nsg-example"

  location            = azurerm_resource_group.main.location

  resource_group_name = azurerm_resource_group.main.name


  security_rule {

    name                       = "Allow-SSH"

    priority                   = 1001

    direction                  = "Inbound"

    access                     = "Allow"

    protocol                   = "Tcp"

    source_port_range          = "*"

    destination_port_range     = "22"

    source_address_prefix      = "*"

    destination_address_prefix = "*"

  }


  security_rule {

    name                       = "Allow-HTTP"

    priority                   = 1002

    direction                  = "Inbound"

    access                     = "Allow"

    protocol                   = "Tcp"

    source_port_range          = "*"

    destination_port_range     = "80"

    source_address_prefix      = "*"

    destination_address_prefix = "*"

  }

}


# Associate NSG to subnet (common practice for Azure "VPC" public subnet to control traffic)

resource "azurerm_subnet_network_security_group_association" "public" {

  subnet_id                 = azurerm_subnet.public.id

  network_security_group_id = azurerm_network_security_group.main.id

}


# Network Interface

resource "azurerm_network_interface" "vm" {

  name                = "nic-vm"

  location            = azurerm_resource_group.main.location

  resource_group_name = azurerm_resource_group.main.name


  ip_configuration {

    name                          = "internal"

    subnet_id                     = azurerm_subnet.public.id

    private_ip_address_allocation = "Dynamic"

    public_ip_address_id          = azurerm_public_ip.vm.id

  }

}


# Linux Virtual Machine (Debian)

resource "azurerm_linux_virtual_machine" "debian_vm" {

  name                = "debian-vm"

  resource_group_name = azurerm_resource_group.main.name

  location            = azurerm_resource_group.main.location

  size                = "Standard_B1s"

  admin_username      = "azureuser"

  network_interface_ids = [

    azurerm_network_interface.vm.id,

  ]


  admin_ssh_key {

    username   = "azureuser"

    public_key = tls_private_key.demo_key.public_key_openssh

  }


  os_disk {

    caching              = "ReadWrite"

    storage_account_type = "Standard_LRS"

  }


  source_image_reference {

    publisher = "Debian"

    offer     = "debian-11"

    sku       = "11"

    version   = "latest"

  }


  computer_name  = "debianvm"

  provision_vm_agent = true

  allow_extension_operations = true

}
