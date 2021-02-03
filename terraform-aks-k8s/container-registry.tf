# Keep Azure container registry name unique with randon number
locals {
  registry_name        = "${var.registry_name}${random_integer.random_int_registry.result}"

}

resource "azurerm_resource_group" "container_registry_rg" {
  location = "${var.location}"
  name     = "${var.resource_group_name}-${var.customer_name}-${var.cluster_name}"

} 

# Keep Azure container registry name somewhat unique
resource "random_integer" "random_int_registry" {
  min = 1
  max = 99999
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.container_registry_rg.name}"
  }
}


resource "azurerm_container_registry" "container_registry" {
  #name                = "${var.registry_name}${var.cluster_name}"
  name                = "${local.registry_name}"
  location            = "${azurerm_resource_group.container_registry_rg.location}"
  resource_group_name = "${azurerm_resource_group.container_registry_rg.name}"
  sku                 = "${var.sku}"

  tags {
        Environment = "${var.tag}-${var.customer_name}-${var.cluster_name}-${var.location}"
    }  
}