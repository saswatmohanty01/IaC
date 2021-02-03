output "id" {
  value = "${azurerm_kubernetes_cluster.k8s.id}"
}

output "client_key" {
    value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.client_key}"
    sensitive   = true
}

output "client_certificate" {
    value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.client_certificate}"
    sensitive   = true
}

output "cluster_ca_certificate" {
    value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.cluster_ca_certificate}"
    sensitive   = true
}

output "cluster_username" {
    value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.username}"
}

output "cluster_password" {
    value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.password}"
    sensitive   = true
}

output "kube_config" {
    value = "${azurerm_kubernetes_cluster.k8s.kube_config_raw}"
    sensitive   = true
}

output "host" {
    value = "${azurerm_kubernetes_cluster.k8s.kube_config.0.host}"
}

output "fqdn" {
  value = "${azurerm_kubernetes_cluster.k8s.fqdn}"
}


output "resourcegroup_name" {
  value = "${azurerm_resource_group.k8s.name}"
}

output "node_resource_group" {
    value = "${azurerm_kubernetes_cluster.k8s.node_resource_group}"
}



output "subnet_id" {
    description = "Subnet ID."
    value = "${azurerm_kubernetes_cluster.k8s.agent_pool_profile.0.vnet_subnet_id}"
}


output "network_plugin" {
  value = "${azurerm_kubernetes_cluster.k8s.network_profile.0.network_plugin}"
}

output "service_cidr" {
  value = "${azurerm_kubernetes_cluster.k8s.network_profile.0.service_cidr}"
}

output "dns_service_ip" {
  value = "${azurerm_kubernetes_cluster.k8s.network_profile.0.dns_service_ip}"
}

output "docker_bridge_cidr" {
  value = "${azurerm_kubernetes_cluster.k8s.network_profile.0.docker_bridge_cidr}"
}

output "pod_cidr" {
  value = "${azurerm_kubernetes_cluster.k8s.network_profile.0.pod_cidr}"
}

output "virtual_network_id" {
  value = "${azurerm_virtual_network.k8s_network.name}"
}

# Public IP address of Installhost VM 
output "public_ip_address_installhost" {
  description = "The public ip address allocated for the resource."
  value       = "${data.azurerm_public_ip.ansibletargethost.ip_address}"
} 