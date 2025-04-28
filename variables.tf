variable "vm_username" {
  type = string
  sensitive = true
}
variable "vm_password" {
  type = string
  sensitive = true
}
variable "db_username" {
  type = string
  sensitive = true
}
variable "db_password" {
  type = string
  sensitive = true
}
# variable "azure_container_name" {
#   type = string
#   default = 
# }
# variable "state_file_name" {
#   type = string
#   default = 
# }
variable "network_name" {
  type = string
  default = "jenkinsNetwork"
}
variable "subnet_name" {
  type = string
  default = "Deployment-subnet"
}
variable "azure_container_registry_name" {
    type = string
    default = "acrPetclinic1234"
}
variable "vm_scale_set_name" {
  type = string
  default = "vmss-example"
}
variable "scale_set_interface_name" {
  type = string
  default = "primary-nic"
}
variable "load_balancer_name" {
  type = string
  default = "example-lb"
}
variable "lb_frontend_name" {
  type = string
  default = "loadbalancer-ip"
}
variable "lb_backend_pool_name" {
  type = string
  default = "lb_address_pool"
}
variable "lb_probe_name" {
  type = string
  default = "example-probe"
}
variable "lb_rule_name" {
  type = string
  default = "example-lb-rule"
}
variable "lb_public_ip_name" {
  type = string
  default = "example-lb-ip"
}
variable "nsg_name" {
  type = string
  default = "example-nsg"
}
variable "mysql_server_name" {
  type = string
  default = "petclinic-sqlserver"
}
variable "mysql_db_name" {
  type = string
  default = "petclinicdb"
}
variable "mysql_rule_name" {
  type = string
  default = "AllowLocalBackend"
}
