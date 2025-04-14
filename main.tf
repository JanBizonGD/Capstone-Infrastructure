terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 4.26.0"
    }
  }
  backend "azurerm" {
      use_cli = true
      use_azuread_auth = true
      storage_account_name = ""
      container_name = "petclinicimage"
      key   = "prod.terraform.tfstate"
  }
}
variable "resource_group_name" {
  type = string
  nullable = false
}

# Step 1: Provider configuration
provider "azurerm" {
  features {}
  resource_provider_registrations = "none" 
}

# Step 2: Define resource group
data "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
}

# Create network 
data "azurerm_virtual_network" "existing_vnet" {
  name                = "jenkinsNetwork"
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["192.168.0.0/16"]
}

# Create a subnet in the existing VNet
resource "azurerm_subnet" "deploy_subnet" {
  name                 = "Deployment-subnet"
  resource_group_name  = data.azurerm_virtual_network.existing_vnet.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.existing_vnet.name
  address_prefixes     = ["192.168.1.0/24"] 
}

# Network interface
resource "azurerm_network_interface" "temp_nic" {
  name                = "temp-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "vm_network_config"
    subnet_id                     = azurerm_subnet.deploy_subnet.id
    private_ip_address_allocation = "Static"
  }
}


# Step 3: Create temporary VM with metadata script for installing Apache
resource "azurerm_linux_virtual_machine" "temp_vm" {
  name                  = "temp-vm"
  location             = data.azurerm_resource_group.rg.location
  resource_group_name  = data.azurerm_resource_group.rg.name
  size                  = "Standard_B1ms"
  network_interface_ids = [azurerm_network_interface.temp_nic.id]
  admin_username       = "adminuser"
  admin_password       = "Password123!"
  os_disk {
    caching    = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

  tags = {
    environment = "testing"
  }

  custom_data = base64encode(<<-EOT
                #cloud-config
                runcmd:
                  - apt-get update
                  - apt-get install -y apache2
                  - echo "<html><body><h1>Server: $(hostname)</h1></body></html>" > /var/www/html/index.html
                  - systemctl start apache2
                  - systemctl enable apache2
                EOT
  )
}

# Step 4: Create an image from the temporary VM
resource "azurerm_image" "vm_image" {
  name                = "vm-image"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  source_virtual_machine_id = azurerm_linux_virtual_machine.temp_vm.id
}

# Step 5: Create scale set with 3 instances using the custom image and load balancer
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "vmss-example"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  sku = "Standard_B1ms"
  source_image_id = azurerm_image.vm_image.id
  admin_username  = "adminuser"
  admin_password  = "Password123!"
  overprovision   = true

  # health_probe {
  #   protocol = "Http"
  #   port     = 80
  #   request_path = "/"
  # }

  tags = {
    environment = "production"
  }

  network_interface {
    name                      = "primary-nic"
    primary                   = true
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.deploy_subnet.id
    }
  }

  depends_on = [azurerm_image.vm_image]
}

# Step 6: Create an external load balancer
resource "azurerm_lb" "example_lb" {
  name                = "example-lb"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  frontend_ip_configuration {
    name                                 = "loadbalancer-ip"
    public_ip_address_id                = azurerm_public_ip.lb_public_ip.id
  }
}

# Other lb resources
resource "azurerm_lb_backend_address_pool" "lb_address_pool" {
  loadbalancer_id = azurerm_lb.example_lb.id
  name = "lb_address_pool"
}

resource "azurerm_lb_probe" "lb_probe" {
  loadbalancer_id = azurerm_lb.example_lb.id
  name                = "example-probe"
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = "30"
  probe_threshold = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id = azurerm_lb.example_lb.id
  name                           = "example-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "loadbalancer-ip"
  backend_address_pool_ids       = [ azurerm_lb_backend_address_pool.lb_address_pool.id ]
  probe_id                       = azurerm_lb_probe.lb_probe.id
}



# Step 7: Create public IP for the load balancer
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "example-lb-ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                  = "Basic"
}

# Step 8: Define firewall rules for accessing load balancer from limited IP addresses
resource "azurerm_network_security_group" "nsg" {
  name                = "example-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "192.168.1.0/24"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "192.168.1.0/24"
    destination_address_prefix = "*"
  }
}

# Step 9: Associate NSG with the load balancer
resource "azurerm_network_interface_security_group_association" "nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.temp_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
