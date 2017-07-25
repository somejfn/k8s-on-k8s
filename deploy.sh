#!/bin/bash

print_usage() {
  echo "Usage: ./deploy.sh -h <API hostname> [-p <non default https port>] -n <namespace>"
  exit 1
}

# Parse args
[ -z "${1}" ] && print_usage
OPTIND=1
while getopts "h:p:n:" opt; do
    case "$opt" in
    h)  APIHOST=${OPTARG}
    ;;
    p)  APIPORT=${OPTARG}
    ;;
    n)  NAMESPACE=${OPTARG}
    ;;
    esac
done
shift $((OPTIND-1))
[ "$1" = "--" ] && shift

if [ -z "{APIHOST}" ] || [ -z "${NAMESPACE}" ] ; then
  print_usage
fi

# Make sure we have a working access to the desired NAMESPACE
# by looking up the default service account
# FIXME...  doest mean we have priv to create stuff in here
if $(which kubectl) get sa/default -n ${NAMESPACE} 1>/dev/null ; then
  echo "CHECK: Access to cluster confirmed"
else
  exit 1
fi

# Generate TLS assets based on provided hostname
if host ${APIHOST} 1>/dev/null ; then
  echo "CHECK: API server host ${APIHOST} resolves"
else
  echo "Can't resolve ${APIHOST}"
  exit 1
fi

# Add port if non default
if [ ! -z "${APIPORT}" ] ; then
  APIHOST="${APIHOST}:${APIPORT}"
fi

# Create certs and kubeconfig
cd ./tls
./make_certs.sh ${APIHOST}


# Creating K8s secrets in infra cluster
for i in apiserver-secret.yaml apiserver-admin-secret.yaml ; do
   $(which kubectl) -n ${NAMESPACE} create -f $i
done

# Creating K8s assets in infra cluster
cd ../manifests
$(which kubectl) -n ${NAMESPACE} create -f etcd/
$(which kubectl) -n ${NAMESPACE} create -f apiserver/

# Check we can connect !
cd ../
echo "Giving a few seconds for the API server to start..."
sleep 15
$(which kubectl) version --kubeconfig=tls/kubeconfig
