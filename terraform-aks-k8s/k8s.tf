# # Configure the Microsoft Azure Provider. Please provide client_id,client_secret,tenant_id for Azure subscription 
 provider "azurerm" {
     subscription_id = "${var.subscription_id}"
     client_id       = "${var.client_id}"
     client_secret   = "${var.client_secret}"
     tenant_id       = "${var.tenant_id}"
 }

#Keep AKS cluster name unique with randon number
locals {
  cluster_name        = "${var.cluster_name}-${random_integer.random_int.result}"

}

resource "azurerm_resource_group" "k8s" {
    name     = "${var.resource_group_name}-${var.customer_name}-${var.cluster_name}"
    location = "${var.location}"
    lifecycle {
    //prevent_destroy = true
  }
}


# Keep the AKS name (and dns label) somewhat unique
resource "random_integer" "random_int" {
  min = 1
  max = 99999
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${azurerm_resource_group.k8s.name}"
  }
} 


# AKS advance networking
resource "azurerm_virtual_network" "k8s_network" {
  name                = "${var.cluster_name}-${var.customer_name}-aks-vnet"
  location            = "${azurerm_resource_group.k8s.location}"
  resource_group_name = "${azurerm_resource_group.k8s.name}"
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "k8s_subnet" {
#  depends_on = [ "azurerm_virtual_network.k8s_network" ] 
  name                      = "${var.cluster_name}-${var.customer_name}-aks-subnet"
  resource_group_name       = "${azurerm_resource_group.k8s.name}"
  address_prefix            = "10.1.0.0/24"
  virtual_network_name      = "${azurerm_virtual_network.k8s_network.name}"
}

resource "azurerm_log_analytics_workspace" "k8slog" {
    name                = "${var.log_analytics_workspace_name}-${var.customer_name}-${var.cluster_name}"
    location            = "${var.log_analytics_workspace_location}"
    resource_group_name = "${azurerm_resource_group.k8s.name}"
    sku                 = "${var.log_analytics_workspace_sku}"
}

resource "azurerm_log_analytics_solution" "k8slog" {
    solution_name         = "ContainerInsights"
    location              = "${azurerm_log_analytics_workspace.k8slog.location}"
    resource_group_name   = "${azurerm_resource_group.k8s.name}"
    workspace_resource_id = "${azurerm_log_analytics_workspace.k8slog.id}"
    workspace_name        = "${azurerm_log_analytics_workspace.k8slog.name}"

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

resource "azurerm_kubernetes_cluster" "k8s" {
    #name                = "${var.cluster_name}-${var.customer_name}"
    name                = "${local.cluster_name}"
    location            = "${azurerm_resource_group.k8s.location}"
    resource_group_name = "${azurerm_resource_group.k8s.name}"
    kubernetes_version  = "${var.k8s_version}"
    #dns_prefix          = "${var.dns_prefix == "" ? var.cluster_name : var.dns_prefix}"
    dns_prefix          = "${var.dns_prefix}${local.cluster_name}"
    lifecycle {
    create_before_destroy = true
  }

    linux_profile {
        admin_username = "${var.agent_admin_user}"

        ssh_key {
            key_data = "${file("${var.ssh_public_key}")}"
        }
    }

    agent_pool_profile {
        name            = "agentpool"
        count           = "${var.agent_count}"
        vm_size         = "${var.agent_vm_sku}"
        os_type         = "Linux"
        os_disk_size_gb = "${var.node_os_disk_size_gb}"
        #advance networking using azure CNI
        vnet_subnet_id = "${azurerm_subnet.k8s_subnet.id}"
        
    }

    service_principal {
        client_id     = "${var.client_id}"
        client_secret = "${var.client_secret}"
    }


    role_based_access_control {
    enabled = true
  }


    addon_profile {
        oms_agent {
        enabled                    = true
        log_analytics_workspace_id = "${azurerm_log_analytics_workspace.k8slog.id}"
        }
    }

    network_profile {
    network_plugin = "azure"
  }

    tags {
        Environment = "${var.tag}-${var.customer_name}-${var.cluster_name}-${var.location}"
    }       
}




# Get AKS cluster config and store it under tenant deployment directory under .kube
resource "null_resource" "getkubeconfig" {
  depends_on = [ "azurerm_kubernetes_cluster.k8s" ]   
  provisioner "local-exec" {
    command = "az aks get-credentials -n ${local.cluster_name} -g ${azurerm_resource_group.k8s.name} -f $PWD/.kube/config"
    on_failure = "fail"
  }

}

