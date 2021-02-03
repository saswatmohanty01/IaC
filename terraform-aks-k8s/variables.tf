# Azure subscription specific secrets
variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}


# Installhost secret variables  for username and password
variable "admin_username" {}

variable "admin_password" {}

#SAP container registry . Should be specific to tenant s-user
variable "sapregistrylogin" {}
variable "sapregistrypassword" {}



#customer_name should be unique string or RID 
variable "customer_name" {
   default = "REPLACE_TENANT_NAME"
}

variable "agent_vm_sku" {
 description = "Azure VM SKU for the agent/worker nodes"
 default     = "Standard_E4_v3"
}


variable "node_os_disk_size_gb" {
 description = "Size in GB of the node's OS disks (default 30)"
 default     = 30
}
variable "agent_count" {
   default = REPLACE_NUMBER_OF_WORKERS
}


variable "agent_admin_user" {
 description = "Admin username for the first user created on the worker nodes"
 default     = "vsadmin"
}

variable "ssh_public_key" {
   default = "~/.ssh/id_rsa.pub"
}


variable "dns_prefix" {
   default = "REPLACE_DNS_PREFIX"
}
#Azure AKS Cluster name to be used. cluster_name has to be unique and should not conflict with existing cluster name
variable cluster_name {
   default = "REPLACE_CLUSTER_NAME"
}

# SAP Data Hub 2.4 vesion requires Azure Kubernetes Service (AKS) running Kubernetes 1.10.x . Refer https://help.sap.com/doc/922191c241c74d00bcbc3efaa06f8606/2.4.latest/en-US/loio922191c241c74d00bcbc3efaa06f8606.pdf
variable "k8s_version" {
 description = "Version of Kubernetes to install on the cluster - see `az aks get-versions --location [location] for valid values`"
 default     = "1.10.13"
}

variable resource_group_name {
   default = "AKS-SDH"
}

variable location {
   default = "REPLACE_LOCATION"
}

variable log_analytics_workspace_name {
   default = "k8sLogAnalyticsWorkspace"
}


# AKS networking
variable "network_profile" {
  description = "Specify network profile for AKS."
  default = "kubenet"
}

# refer https://azure.microsoft.com/global-infrastructure/services/?products=monitor for log analytics available regions. Only few regions are available.
variable log_analytics_workspace_location {
   default = "eastus"
}

# refer https://azure.microsoft.com/pricing/details/monitor/ for log analytics pricing
variable log_analytics_workspace_sku {
   default = "Standard"
}


# Azure container registry Variables
variable "registry_name" {
 description = "(Required) Specifies the name of the Container Registry. Changing this forces a new resource to be created."
 default     = "acr"
}

variable "sku" {
 description = "(Optional) The SKU name of the the container registry. Possible values are Classic (which was previously Basic), Basic, Standard and Premium."
 default     = "Standard"
}

# Common variables
variable "tag" {
 description = "Tag for Environment"
 default     = "AKS-SAP-DATA-HUB"
}
