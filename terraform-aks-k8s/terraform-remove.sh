#!/bin/bash
CURRDIR=`dirname ${0}`
UNINSTALLLOG=$CURRDIR/uninstall.log
####SCRIPT OUTPUT TO LOG FILE####
teelogger(){
log=$1
while read line ; do
echo "$(date +"%x %T") :: $line" | tee -a $log
done
           }
{

#http_proxy has to export for connecting to internet and download terraform module
export http_proxy=<proxy_address>
export https_proxy=<proxy_address>

if [ ! -f /usr/bin/terraform ]; then
curl -sS https://releases.hashicorp.com/terraform/0.11.13/terraform_0.11.13_linux_amd64.zip -o /tmp/terra.zip
cd /tmp/
unzip -o terra.zip
mv terraform /usr/bin/
chmod +x /usr/bin/terraform
fi

if [ ! -d .terraform ]; then
/usr/bin/terraform version
/usr/bin/terraform init
#/usr/bin/terraform init -backend-config="backend.tfvars"
/usr/bin/terraform validate
/usr/bin/terraform destroy -force
fi
#/usr/bin/terraform init -backend-config="backend.tfvars
/usr/bin/terraform init
/usr/bin/terraform validate
/usr/bin/terraform destroy -force
sleep 10
#terraform destroy again due to Azure bug which fails to delete subnet and looking for vnet 
/usr/bin/terraform destroy -force

} | teelogger $UNINSTALLLOG

