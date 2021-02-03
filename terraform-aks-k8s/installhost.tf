# # Use AKS state data
 data "terraform_remote_state" "k8s" {
   backend = "local"

   config = {
     path = "terraform.tfstate"
   }
 }

# Use AKS subnet for Installhost deployment
data "azurerm_subnet" "installhost_subnet" { 
  name                 = "${azurerm_subnet.k8s_subnet.name}"
  virtual_network_name = "${azurerm_virtual_network.k8s_network.name}"
  resource_group_name  = "${azurerm_resource_group.k8s.name}"
}


# Create new Resource group for installhost for AKS cluster specific to Tenant 
resource "azurerm_resource_group" "installhost_rg" { 
  depends_on = [ "azurerm_virtual_network.k8s_network" ]   
  location = "${var.location}"
  name     = "Installhost-${var.customer_name}-${var.cluster_name}"
}
  
# Create public IPs
resource "azurerm_public_ip" "installhostpublicip" {
    name                         = "installhostPublicIP"
    location                     = "${var.location}"
    resource_group_name          = "${azurerm_resource_group.installhost_rg.name}"
    allocation_method            = "Dynamic"
    # domain_name_label            = "${var.public_ip_dns["name"]}"   

    tags {
        Environment = "${var.tag}-${var.customer_name}-${var.cluster_name}-${var.location}"
    }  
} 

# Create Network Security Group and rule for allowing ssh port to external 
resource "azurerm_network_security_group" "installhostnsg" {
    name                = "installhostNetworkSecurityGroup"
    location            = "${var.location}"
    resource_group_name = "${azurerm_resource_group.installhost_rg.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
       
    }

    tags {
        Environment = "${var.tag}-${var.customer_name}-${var.cluster_name}-${var.location}"
    }  

}    


# Create network interface for installhost 
resource "azurerm_network_interface" "installhostnic" {
    name                      = "installhostNIC"
    location                  = "${var.location}"
    resource_group_name       = "${azurerm_resource_group.installhost_rg.name}"
    network_security_group_id = "${azurerm_network_security_group.installhostnsg.id}"

    ip_configuration {
        name                          = "installhostNicConfiguration"
        subnet_id                     = "${data.azurerm_subnet.installhost_subnet.id}"
        private_ip_address_allocation = "dynamic"
        #private_ip_address            = "${var.private_ip_address}"  
        public_ip_address_id          = "${azurerm_public_ip.installhostpublicip.id}"
        
    }

    tags {
        Environment = "${var.tag}-${var.customer_name}-${var.cluster_name}-${var.location}"
    } 
} 

# Generate random text for a unique storage account name for installhost
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.installhost_rg.name}"
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "installhoststorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.installhost_rg.name}"
    location                    = "${var.location}"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        Environment = "${var.tag}-${var.customer_name}-${var.cluster_name}-${var.location}"
    } 
}


# Create storage account for SAP Data Hub 
resource "azurerm_storage_account" "sapdatahubstorageaccount" {
    name                        = "sdh${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.k8s.name}"
    location                    = "${var.location}"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags {
        Environment = "${var.tag}-${var.customer_name}-${var.cluster_name}-${var.location}"
    } 
} 
# Create Azure storage container in sapdatahubstorageaccount
resource "azurerm_storage_container" "sapdatahubstoragecontainer" {
  name                  = "${data.azurerm_kubernetes_cluster.k8sapi.name}"
  resource_group_name   = "${azurerm_resource_group.k8s.name}"
  storage_account_name  = "${azurerm_storage_account.sapdatahubstorageaccount.name}"
  container_access_type = "private"
}


# Create virtual machine
resource "azurerm_virtual_machine" "installhost" {
    depends_on = [ "azurerm_kubernetes_cluster.k8s" ] 
    name                  = "Installhost-${var.customer_name}-${var.cluster_name}"
    location              = "${azurerm_network_interface.installhostnic.location}"
    resource_group_name   = "${azurerm_resource_group.installhost_rg.name}"
    network_interface_ids = ["${azurerm_network_interface.installhostnic.id}"]
    vm_size               = "Standard_DS3_v2"
    delete_os_disk_on_termination = true 
    delete_data_disks_on_termination = true

    storage_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7.5"
    version   = "latest"
    }
    storage_os_disk {
    name              = "Installhostdisk1-${var.customer_name}-${var.cluster_name}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    disk_size_gb      = "80"
    managed_disk_type = "Standard_LRS"
    }
    os_profile {
    computer_name  = "installhost"
    admin_username = "${var.admin_username}"
    admin_password = "${var.admin_password}"
    }
    os_profile_linux_config {
    disable_password_authentication = false
    }
    tags {
        Environment = "${var.tag}-${var.customer_name}-${var.cluster_name}-${var.location}"
    } 



 }

 

# Get SAP Data Hub installation requirement specific data 
# Store as data for installhost VM Azure public IP
data "azurerm_public_ip" "ansibletargethost" {
  depends_on = [ "azurerm_public_ip.installhostpublicip" ]
  
  name                = "${azurerm_public_ip.installhostpublicip.name}"
  resource_group_name = "${azurerm_virtual_machine.installhost.resource_group_name}"
} 
# Store as data for Azure storage account details from sapdatahubstorageaccount blob 
data "azurerm_storage_account" "sapdatahubstorageaccount" {
  name                = "${azurerm_storage_account.sapdatahubstorageaccount.name}"
  resource_group_name = "${azurerm_resource_group.k8s.name}"

}

# Store as data for Azure container registry 
data "azurerm_container_registry" "datahubcontainerregistry" {
  name                = "${azurerm_container_registry.container_registry.name}"
  resource_group_name = "${azurerm_resource_group.container_registry_rg.name}"
}

# Store AKS cluster API end point FQDN
data "azurerm_kubernetes_cluster" "k8sapi" {
  name                = "${azurerm_kubernetes_cluster.k8s.name}"
  resource_group_name = "${azurerm_resource_group.k8s.name}"
}


# Store AKS resource group name 
data "azurerm_resource_group" "k8srg" {
  name                = "${azurerm_storage_account.sapdatahubstorageaccount.resource_group_name}"
  
}


#### outputfrom data source #####
# Get targethost Azure public IP as output 
output "ansibletargethost" {
  value = "${data.azurerm_public_ip.ansibletargethost.ip_address}"
}

# Get sapdatahubstorageaccount name as output 
 output "sapdatahubstorageaccount-name" {
   value = "${data.azurerm_storage_account.sapdatahubstorageaccount.name}"
 }

# Get sapdatahubstorageaccount primary access key as output
 output "sapdatahubstorageaccount-primarykey" {
   value = "${data.azurerm_storage_account.sapdatahubstorageaccount.primary_access_key}"
   sensitive   = true
 }

# Get datahubcontainerregistry name
output "containerregistryname" {
  value = "${data.azurerm_container_registry.datahubcontainerregistry.name}"
}

# Get datahubcontainerregistry login server
output "containerloginserver" {
  value = "${data.azurerm_container_registry.datahubcontainerregistry.login_server}"
}

# get AKS cluster name
output "k8sclustername" {
  value = "${data.azurerm_kubernetes_cluster.k8sapi.name}"
}

# Get AKS cluster API end point FQDN
output "k8sapi" {
  value = "${data.azurerm_kubernetes_cluster.k8sapi.fqdn}"
}

# Get AKS cluster resource group 
output "k8srg" {
  value = "${data.azurerm_resource_group.k8srg.name}"
}


# Delete existing ansible.zip file if any
resource "null_resource" "deletezip" {
  depends_on = [ "azurerm_virtual_machine.installhost" ]
    provisioner "local-exec" {
      command = "rm -rf $PWD/ansible.zip"
      on_failure = "continue"
   }
}


# zip  media zip file and ansible files  
  data "archive_file" "archiveupload" {
  depends_on = [ "null_resource.deletezip" ]
  type        = "zip"
  source_dir = "upload/ansible"
  output_path = "ansible.zip"
  }

# Upload upload ansible directory zip file to Azure blob 
resource "azurerm_storage_blob" "ansibleblob" {
  depends_on = [ "data.archive_file.archiveupload" ]
  name                   = "ansible.zip"
  resource_group_name    = "${azurerm_storage_account.sapdatahubstorageaccount.resource_group_name}"
  storage_account_name   = "${azurerm_storage_account.sapdatahubstorageaccount.name}"
  storage_container_name = "${data.azurerm_kubernetes_cluster.k8sapi.name}"
  type                   = "block"
  size                   = "5120"
  source                 = "${data.archive_file.archiveupload.output_path}"
  attempts               = "5"
}

output "bloburlansible" {
  value = "${azurerm_storage_blob.ansibleblob.url}"
}

# Upload SAP Installation zip to azure blob
resource "azurerm_storage_blob" "sapmediablob" {
  depends_on = [ "azurerm_storage_blob.ansibleblob" ]
  name                   = "sapmedia.zip"
  resource_group_name    = "${azurerm_storage_account.sapdatahubstorageaccount.resource_group_name}"
  storage_account_name   = "${azurerm_storage_account.sapdatahubstorageaccount.name}"
  storage_container_name = "${data.azurerm_kubernetes_cluster.k8sapi.name}"
  type                   = "block"
  size                   = "5120"
  source                 = "upload/installation-media/DHFOUNDATION04_1-80004015.ZIP"
  attempts               = "5"
}

output "bloburlsapmedia" {
  value = "${azurerm_storage_blob.sapmediablob.url}"
}



# Set password for root user  using az vm command as there is no connection over ssh from customer network
resource "null_resource" "rootpassword" {
  depends_on = [ "azurerm_virtual_machine.installhost" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'echo ${var.admin_password} | passwd --stdin root'"
      on_failure = "fail"
   }
}


# Subscribe to RHEL  
resource "null_resource" "subscriberhel" {
  depends_on = [ "null_resource.rootpassword" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'subscription-manager register --username ryzasss666 --password UbFzhbyZX3oWkq8FGb81 --auto-attach --force && sleep 30'"
      on_failure = "fail"
   }
}


# Subscribe to subscription-manager repos --enable rhel-7-server-ansible-2.6-rpms
resource "null_resource" "subscribeansible" {
  depends_on = [ "null_resource.subscriberhel" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'subscription-manager refresh && subscription-manager repos --enable rhel-7-server-ansible-2.6-rpms'"
      on_failure = "fail"
   }
}


# Install ansible from RHEL official subscription
resource "null_resource" "installansible" {
  depends_on = [ "null_resource.subscribeansible" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'yum install -y ansible'"
      on_failure = "fail"
   }
}


#Install azcopy tool 
resource "null_resource" "install-azcopy" {
  depends_on = [ "null_resource.installansible" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'yum install -y libunwind icu && wget -O azcopy.tar.gz https://aka.ms/downloadazcopylinuxrhel6 && tar -xf azcopy.tar.gz && ./install.sh'"
      on_failure = "fail"
   }
}


#Download ansible.zip from azure blob using azcopy 
resource "null_resource" "ansibledownloadfromblob" {
  depends_on = [ "null_resource.install-azcopy" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'azcopy  --source ${azurerm_storage_blob.ansibleblob.url} --destination /opt/ansible.zip --source-key ${data.azurerm_storage_account.sapdatahubstorageaccount.primary_access_key}'"
      on_failure = "fail"
   }
}


#Download sapmedia.zip from azure blob using azcopy
resource "null_resource" "sapmediadownloadfromblob" {
  depends_on = [ "null_resource.ansibledownloadfromblob" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'azcopy  --source ${azurerm_storage_blob.sapmediablob.url} --destination /opt/sapmedia.zip --source-key ${data.azurerm_storage_account.sapdatahubstorageaccount.primary_access_key}'"
      on_failure = "fail"
   }
}



#Extract ansible.zip and sapmedia.zip 
resource "null_resource" "extract-zip" {
  depends_on = [ "null_resource.sapmediadownloadfromblob" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'unzip -o -d /opt/ansible  /opt/ansible.zip && unzip -o -d /opt /opt/sapmedia.zip'"
      on_failure = "fail"
   }
}


#Install python27-python-pip 
resource "null_resource" "prerequisites" {
  depends_on = [ "null_resource.extract-zip" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'yum -y install python27-python-pip && scl enable python27 bash >> /root/install.log'"
      on_failure = "fail"
   }
}


#Ansible-playbook for installing requirements before sap data hub installation
resource "null_resource" "datahubreq" {
  depends_on = [ "null_resource.prerequisites" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'ansible-playbook /opt/ansible/requirements.yml -e client_id=${var.client_id} -e client_secret=${var.client_secret} -e tenant_id=${var.tenant_id} -e resourcegroup_name=${var.resource_group_name}-${var.customer_name}-${var.cluster_name} -e cluster_name=${data.azurerm_kubernetes_cluster.k8sapi.name} -vvv >> /root/install.log'"
      on_failure = "fail"
   }
}



#SAP data hub environment configuration for installation
resource "null_resource" "datahubenv" {
  depends_on = [ "null_resource.datahubreq" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts '/bin/ansible-playbook /opt/ansible/datahubenv.yml -e client_id=${var.client_id} -e client_secret=${var.client_secret} -e tenant_id=${var.tenant_id} -e resourcegroup_name=${var.resource_group_name}-${var.customer_name}-${var.cluster_name} -e cluster_name=${data.azurerm_kubernetes_cluster.k8sapi.name} -e containerregistryname=${data.azurerm_container_registry.datahubcontainerregistry.name} -vvv >> /root/install.log'"
      on_failure = "fail"
   }
}



#Trigger install.sh script with parameter 
resource "null_resource" "triggerinstall" {
  depends_on = [ "null_resource.datahubenv" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'export KUBECONFIG=/root/.kube/config && /bin/ansible-playbook /opt/ansible/installscript.yml -e containerregistryname=${data.azurerm_container_registry.datahubcontainerregistry.name}  -e client_secret=${var.client_secret} -e cluster_name=${data.azurerm_kubernetes_cluster.k8sapi.name} -e containerloginserver=${data.azurerm_container_registry.datahubcontainerregistry.login_server} -e vorasystempassword=${var.admin_password} -e voraadminpassword=${var.admin_password} -e wasbaccountname=${data.azurerm_storage_account.sapdatahubstorageaccount.name} -e wasbaccountkey=${data.azurerm_storage_account.sapdatahubstorageaccount.primary_access_key} -e wasbpath=${data.azurerm_kubernetes_cluster.k8sapi.name} -e certdomain=${data.azurerm_kubernetes_cluster.k8sapi.fqdn} -e imagepullsecret=${var.client_secret} -e sapreglogin=${var.sapregistrylogin} -e sapregpassword=${var.sapregistrypassword} -vvv >> /root/install.log'"
      on_failure = "continue"
   }
}

#Check for ansible-playbook process and wait till ansible-process is not completed.This is dirty fix for az vm bug which timed out for long running process triggered for SAP Data Hub install.sh script
#Bug filed with Azure team https://github.com/Azure/azure-cli/issues/8967
resource "null_resource" "watchansibleprocess" {
  depends_on = [ "null_resource.triggerinstall" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'while ps axg | grep -vw grep | grep -w ansible-playbook  > /dev/null; do sleep 1 && echo Installation is in progress using ansible-playbok;  done'"
      on_failure = "continue"
   }
}


#Second check for ansible-playbook. Azure az vm run-command can run for 90 minutes and timed out. Incase ansible-playbook calls SAP install.sh take longer than 180 minutes or 3 hours then second check will keep terraform running without failure
#Refer https://docs.microsoft.com/en-us/azure/virtual-machines/linux/run-command#restrictions and https://github.com/Azure/azure-cli/issues/8967. In case Azure team increase timed out more than 90 minutes then second check if not required
resource "null_resource" "2ndwatchansibleprocess" {
  depends_on = [ "null_resource.watchansibleprocess" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'while ps axg | grep -vw grep | grep -w ansible-playbook  > /dev/null; do sleep 1 && echo Installation is in progress using ansible-playbok;  done'"
      on_failure = "fail"
   }
}


#Expose vsystem POD to Azure LB public IP
resource "null_resource" "vsystempod" {
  depends_on = [ "null_resource.2ndwatchansibleprocess" ]
    provisioner "local-exec" {
      command = "az vm run-command invoke -g '${azurerm_virtual_machine.installhost.resource_group_name}' -n '${azurerm_virtual_machine.installhost.resource_group_name}' --command-id RunShellScript --scripts 'export KUBECONFIG=/root/.kube/config && /bin/ansible-playbook /opt/ansible/vsystempod.yml -vvv >> /root/install.log'"
      on_failure = "fail"
  }
}

  
#Get vsystem pod Azure LoadBalancer IP and port details
resource "null_resource" "vsystemip" {
  depends_on = [ "null_resource.vsystempod" ]
  provisioner "local-exec" {
    command = "/usr/local/bin/kubectl --kubeconfig $PWD/.kube/config get svc vsystem -n sdh > $PWD/vsystem-publicip.log"
    on_failure = "fail"
  }
}
 





