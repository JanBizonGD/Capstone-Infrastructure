terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~> 3.40.0"
    }
  }
  backend "azurerm" {
      use_cli = true
      use_azuread_auth = true
      storage_account_name = "" #var.azure_storage_account
      container_name = "petclinicimage"
      key   = "prod.terraform.tfstate"
      # tenant_id = ""
      # client_id = ""
      # client_secret = ""
      # subscription_id=""
  }
}

# Step 1: Provider configuration
provider "azurerm" {
  features {}

  # subscription_id = ""
  # client_id = ""
  # client_secret = ""
  # tenant_id = ""
}

# Step 2: Define resource group
resource "azurerm_resource_group" "rg" {
  name     = "rg-example"
  location = "East US"
}

# Step 3: Create temporary VM with metadata script for installing Apache
resource "azurerm_virtual_machine" "temp_vm" {
  name                  = "temp-vm"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  size                  = "Standard_B1ms"
  network_interface_ids = [azurerm_network_interface.temp_nic.id]
  admin_username       = "adminuser"
  admin_password       = "Password123!"
  os_disk {
    caching    = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "temp-vm"
    admin_username = "adminuser"
    admin_password = "Password123!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }

  tags = {
    environment = "testing"
  }

  custom_data = <<-EOT
                #cloud-config
                runcmd:
                  - apt-get update
                  - apt-get install -y apache2
                  - echo "<html><body><h1>Server: $(hostname)</h1></body></html>" > /var/www/html/index.html
                  - systemctl start apache2
                  - systemctl enable apache2
                EOT
}

# Step 4: Create an image from the temporary VM
resource "azurerm_image" "vm_image" {
  name                = "vm-image"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  source_virtual_machine_id = azurerm_virtual_machine.temp_vm.id
}

# Step 5: Create scale set with 3 instances using the custom image and load balancer
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "vmss-example"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku {
    name     = "Standard_B1ms"
    capacity = 3
  }
  source_image_id = azurerm_image.vm_image.id
  admin_username  = "adminuser"
  admin_password  = "Password123!"
  overprovision   = true

  health_probe {
    protocol = "Http"
    port     = 80
    request_path = "/"
  }

  tags = {
    environment = "production"
  }

  network_interface {
    name                      = "primary-nic"
    primary                   = true
    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.subnet.id
    }
  }

  upgrade_policy {
    mode = "Manual"
  }

  depends_on = [azurerm_image.vm_image]
}

# Step 6: Create an external load balancer
resource "azurerm_lb" "example_lb" {
  name                = "example-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  front_end_ip_configuration {
    name                                 = "loadbalancer-ip"
    public_ip_address_id                = azurerm_public_ip.lb_public_ip.id
  }

  backend_address_pool {
    name = "example-backend-pool"
  }

  probes {
    name                = "example-probe"
    protocol            = "Http"
    port                = 80
    request_path        = "/"
    interval            = "30"
    unhealthy_threshold = 2
  }

  load_balancing_rule {
    name                           = "example-lb-rule"
    protocol                       = "Tcp"
    frontend_port                  = 80
    backend_port                   = 80
    frontend_ip_configuration_name = "loadbalancer-ip"
    backend_address_pool_id       = azurerm_lb_backend_address_pool.example_lb_backend_pool.id
    probe_id                       = azurerm_lb_probe.example_lb_probe.id
  }
}

# Step 7: Create public IP for the load balancer
resource "azurerm_public_ip" "lb_public_ip" {
  name                = "example-lb-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                  = "Basic"
}

# Step 8: Define firewall rules for accessing load balancer from limited IP addresses
resource "azurerm_network_security_group" "nsg" {
  name                = "example-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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
