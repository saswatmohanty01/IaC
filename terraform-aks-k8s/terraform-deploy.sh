#!/bin/bash
CURRDIR=`dirname ${0}`
INSTALLLOG=$CURRDIR/install.log
####SCRIPT OUTPUT TO LOG FILE####
teelogger(){
log=$1
while read line ; do
echo "$(date +"%x %T") :: $line" | tee -a $log
done
           }
{

CURRDIR=`dirname ${0}`
if [ ! -f /usr/bin/terraform ]; then
curl -sS https://releases.hashicorp.com/terraform/0.11.13/terraform_0.11.13_linux_amd64.zip -o /tmp/terra.zip
cd /tmp/
unzip -o terra.zip
mv terraform /usr/bin/
chmod +x /usr/bin/terraform
fi
cd ${CURRDIR}
/usr/bin/terraform version
#/usr/bin/terraform init -backend-config="backend.tfvars"
export http_proxy=<proxy_address>
export https_proxy=<proxy_address>
/usr/bin/terraform init
/usr/bin/terraform validate
/usr/bin/terraform plan -out=out.plan
/usr/bin/terraform apply "out.plan"
/usr/bin/terraform output -json > $PWD/sdhconfig.json

} | teelogger $INSTALLLOG


