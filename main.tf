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
      container_name = "petclinicimage" //var.azure_container_name
      key   = "prod.terraform.tfstate" //var.state_file_name
  }
}
variable "resource_group_name" {
  type = string
  nullable = false
}

# Provider configuration
provider "azurerm" {
  features {}
  resource_provider_registrations = "none" 
}

data "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
} 
data "azurerm_virtual_network" "existing_vnet" {
  name                = var.network_name
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Create a subnet in the existing VNet
resource "azurerm_subnet" "deploy_subnet" {
  name                 = var.subnet_name
  resource_group_name  = data.azurerm_virtual_network.existing_vnet.resource_group_name
  virtual_network_name = data.azurerm_virtual_network.existing_vnet.name
  address_prefixes     = ["10.1.2.0/24"] 
  # service_endpoints    = ["Microsoft.Storage"]

  # delegation {
  #   name = "newsub"
  #   service_delegation {
  #     name = "Microsoft.DBforMySQL/flexibleServers"
  #     actions = [
  #       "Microsoft.Network/virtualNetworks/subnets/join/action",
  #     ]
  #   }
  # }
}


resource "azurerm_container_registry" "acr" {
  name                = var.azure_container_registry_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Standard"
  admin_enabled       = true
}
output "acr_username" {
  value = azurerm_container_registry.acr.admin_username
  sensitive = true
}
output "acr_password" {
  value = azurerm_container_registry.acr.admin_password
  sensitive = true
}




resource "azurerm_lb_nat_pool" "lbnatpool" {
  resource_group_name            = data.azurerm_resource_group.rg.name
  name                           = "ssh"
  loadbalancer_id                = azurerm_lb.example_lb.id
  protocol                       = "Tcp"
  frontend_port_start            = 50001
  frontend_port_end              = 50003
  backend_port                   = 22
  frontend_ip_configuration_name = var.lb_frontend_name
}


# Create scale set with 3 instances using the custom image and load balancer
resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = var.vm_scale_set_name
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  depends_on = [ azurerm_lb_nat_pool.lbnatpool ]
  overprovision = false

  instances = 3

  os_disk {
    caching = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  sku = "Standard_B2ms"
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  admin_username  = var.vm_username
  admin_password  = var.vm_password
  disable_password_authentication = false

  tags = {
    environment = "production"
  }

  network_interface {
    name                      = var.scale_set_interface_name
    primary                   = true
    network_security_group_id = azurerm_network_security_group.nsg.id

    ip_configuration {
      name                          = "internal"
      primary   = true
      subnet_id                     = azurerm_subnet.deploy_subnet.id
      load_balancer_backend_address_pool_ids = [ azurerm_lb_backend_address_pool.lb_address_pool.id ]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.lbnatpool.id]
    }

  }

  custom_data = base64encode(<<-EOT
#!/bin/bash
apt update && apt install -y docker
apt update && apt install -y docker-buildx
apt update && apt install -y openjdk-21-jdk
apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common
apt update && apt install -y sudo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb https://download.docker.com/linux/ubuntu focal stable"
apt update && sudo apt install -y containerd.io
sudo apt install -y docker-ce
EOT
)
# Tabs may be a problem here

}
# output "instance_username" {
#   value = azurerm_linux_virtual_machine_scale_set.vmss.admin_username
#   sensitive = true
# }
# output "instance_password" {
#   value = azurerm_linux_virtual_machine_scale_set.vmss.admin_password
#   sensitive = true
# }



# Create load balancer
resource "azurerm_lb" "example_lb" {
  name                = var.load_balancer_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  frontend_ip_configuration {
    name                                 = var.lb_frontend_name
    public_ip_address_id                = azurerm_public_ip.lb_public_ip.id
  }
}

# Other lb resources
resource "azurerm_lb_backend_address_pool" "lb_address_pool" {
  loadbalancer_id = azurerm_lb.example_lb.id
  name = var.lb_backend_pool_name
}

data "azurerm_lb_backend_address_pool" "vmss_nics" {
  name = var.lb_backend_pool_name
  loadbalancer_id = azurerm_lb.example_lb.id

  depends_on = [ azurerm_lb_backend_address_pool.lb_address_pool ]
}

data "azurerm_virtual_machine_scale_set" "vmss" {
  name = azurerm_linux_virtual_machine_scale_set.vmss.name
  resource_group_name = azurerm_linux_virtual_machine_scale_set.vmss.resource_group_name

  depends_on = [ azurerm_linux_virtual_machine_scale_set.vmss ]
}

output "private_ips" {
  value = data.azurerm_virtual_machine_scale_set.vmss.instances.*.private_ip_address
}


resource "azurerm_lb_probe" "lb_probe" {
  loadbalancer_id = azurerm_lb.example_lb.id
  name                = var.lb_probe_name
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = "30"
  probe_threshold = 2
}

resource "azurerm_lb_rule" "lb_rule" {
  loadbalancer_id = azurerm_lb.example_lb.id
  name                           = var.lb_rule_name
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = var.lb_frontend_name
  backend_address_pool_ids       = [ azurerm_lb_backend_address_pool.lb_address_pool.id ]
  probe_id                       = azurerm_lb_probe.lb_probe.id
}



# Create public IP for the load balancer
resource "azurerm_public_ip" "lb_public_ip" {
  name                = var.lb_public_ip_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
}
output "lb_ip" {
  value = azurerm_public_ip.lb_public_ip.ip_address
}

# Define firewall rules for accessing load balancer from limited IP addresses
resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
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
    source_address_prefix      = "0.0.0.0/0"
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
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }

   security_rule {
     access                                     = "Allow"
     destination_address_prefix                 = "*"
     destination_port_range                     = "80"
     direction                                  = "Outbound"
     name                                       = "AllowAnyCustom80Outbound"
     priority                                   = 210
     protocol                                   = "*"
     source_address_prefix                      = "*"
     source_port_range                          = "*"
    }
}

# Database
resource "azurerm_mysql_flexible_server" "my_sql_server" {
  name                   = var.mysql_server_name
  resource_group_name    = data.azurerm_resource_group.rg.name
  location               = data.azurerm_resource_group.rg.location
  administrator_login    = var.db_username
  administrator_password = var.db_password
  backup_retention_days  = 7
  sku_name               = "GP_Standard_D2ds_v4"//"B_Standard_B1s"
  delegated_subnet_id = azurerm_subnet.deploy_subnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.sql_dns.id
  maintenance_window {
    day_of_week  = 0
    start_hour   = 8
    start_minute = 0
  }
  storage {
    iops    = 360
    size_gb = 20
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.sql_dns_link]
}

resource "azurerm_mysql_flexible_database" "example" {
  name                = var.mysql_db_name
  resource_group_name = data.azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.my_sql_server.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

output "sql_uri" {
  value = azurerm_mysql_flexible_server.my_sql_server.fqdn
}


resource "azurerm_public_ip" "nat_ip" {
  name                = "nat-ip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  name                = "nat-gateway"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku_name            = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "nat_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat.id
  public_ip_address_id = azurerm_public_ip.nat_ip.id
}

resource "azurerm_subnet_nat_gateway_association" "nat_assoc" {
  subnet_id      = azurerm_subnet.deploy_subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat.id
}


# Private Endpoint
resource "azurerm_private_endpoint" "sql_pe" {
  name                = "sql-pe"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.deploy_subnet.id

  private_service_connection {
    name                           = "sql-privatesc"
    private_connection_resource_id = azurerm_mysql_flexible_server.my_sql_server.id
    is_manual_connection           = false
    subresource_names              = ["mysqlServer"]
  }
  private_dns_zone_group {
    name                 = "dns-zone-group1"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql_dns.id]
  }
}

resource "azurerm_private_dns_zone" "sql_dns" {
  name                = "privatelink.mysql.database.azure.com"
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "sql_dns_link" {
  name                  = "sql-dns-link"
  resource_group_name   = data.azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql_dns.name
  virtual_network_id    = data.azurerm_virtual_network.existing_vnet.id

  depends_on = [ azurerm_subnet.deploy_subnet ]
}

# resource "azurerm_private_dns_a_record" "sql_dns_record" {
#   name                = azurerm_mysql_flexible_server.my_sql_server.name
#   zone_name           = azurerm_private_dns_zone.sql_dns.name
#   resource_group_name = data.azurerm_resource_group.rg.name
#   ttl                 = 300
#   records             = [azurerm_private_endpoint.sql_pe.private_service_connection[0].private_ip_address]
# }
