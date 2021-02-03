#!/bin/bash
CURRENTDIR=`dirname ${0}`
cd ${CURRENTDIR}
VARIABLEFILENAME="variables.tf"
#BACKENDTFVARS="backend.tfvars"
usage()
{
   echo "$0 : -t <tenant name> -n <cluster name> -d <dns prefix> -w <number of workers> -l <location>"
   exit 255
}
while getopts 't:n:d:w:l:' OPTION; do
  case "$OPTION" in
    t)
      TENANT_NAME="$OPTARG"
      TENANT_NAME=`echo ${TENANT_NAME} | sed 's/^ //' | sed 's/\"//g'`
      ;;
    n)
      CLUSTER_NAME="$OPTARG"
      CLUSTER_NAME=`echo ${CLUSTER_NAME} | sed 's/^ //' | sed 's/\"//g'`
      ;;
    d)
      DNS_PREFIX="$OPTARG"
      DNS_PREFIX=`echo ${DNS_PREFIX} | sed 's/^ //' | sed 's/\"//g'`
      ;;
    w)
      NUMBER_OF_WORKERS="$OPTARG"
      NUMBER_OF_WORKERS=`echo ${NUMBER_OF_WORKERS} | sed 's/^ //' | sed 's/\"//g'`
      ;;
    l)
      LOCATION="$OPTARG"
      LOCATION=`echo ${LOCATION} | sed 's/^ //' | sed 's/\"//g'`
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done
   
sed -i -e "s/REPLACE_TENANT_NAME/${TENANT_NAME}/" \
       -e "s/REPLACE_NUMBER_OF_WORKERS/${NUMBER_OF_WORKERS}/" \
       -e "s/REPLACE_DNS_PREFIX/${DNS_PREFIX}/" \
       -e "s/REPLACE_CLUSTER_NAME/${CLUSTER_NAME}/" \
       -e "s/REPLACE_LOCATION/${LOCATION}/" ${VARIABLEFILENAME}

#replace clustername in backend.tfvars for creating new key in blob for AKS cluster for keeping terraform states
#sed -i -e "s/REPLACE_CLUSTER_NAME/${CLUSTER_NAME}/" ${BACKENDTFVARS} 
