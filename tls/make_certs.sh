#!/bin/bash

APIURL=$1

[ -z "${APIURL}" ] && echo "Usage: make_cert.sh apihost[:port]" && exit 1
APIHOST=$(echo ${APIURL} | cut -f1 -d":")

# Init CA
cfssl gencert -initca ca-csr.json | cfssljson -bare ca

# Apiserver
cat <<EOF> kube-apiserver-server-csr.json
{
  "CN": "kube-apiserver",
  "hosts": [
    "127.0.0.1",
    "kubernetes",
    "${APIHOST}"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "API Server",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
-ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-profile=server \
kube-apiserver-server-csr.json | cfssljson -bare kube-apiserver-server


# KCM
#...

# Kube-proxy
#...

# Admin certs
cfssl gencert \
-ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-profile=client \
kubernetes-admin-user.csr.json | cfssljson -bare kubernetes-admin-user



cat <<EOF> apiserver-secret.yaml
apiVersion: v1
data:
  apiserver.crt: $(cat kube-apiserver-server.pem | base64 | tr -d '\n')
  apiserver.key: $(cat kube-apiserver-server-key.pem | base64 | tr -d '\n')
  ca.crt: $(cat ca.pem | base64 | tr -d '\n')
  etcd-ca.crt: ""
  etcd-client.crt: ""
  etcd-client.key: ""
kind: Secret
metadata:
  name: kube-apiserver
type: Opaque
EOF


# Gen kubeconfig file
cat <<EOF> kubeconfig
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    server: https://${APIURL}
    certificate-authority-data: $(cat ca.pem | base64 | tr -d '\n')
users:
- name: admin
  user:
    client-certificate-data: $(cat kubernetes-admin-user.pem | base64 | tr -d '\n')
    client-key-data: $(cat kubernetes-admin-user-key.pem | base64 | tr -d '\n')
contexts:
- context:
    cluster: local
    user: admin
EOF


# Store kubeconfig as a secret
cat <<EOF> apiserver-admin-secret.yaml
apiVersion: v1
data:
  kubeconfig: $(cat kubeconfig | base64 | tr -d '\n')
kind: Secret
metadata:
  name: admin-kubeconfig
type: Opaque
EOF
