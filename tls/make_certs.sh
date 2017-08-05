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
    "10.3.0.1",
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


# Scheduler
cfssl gencert \
-ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-profile=client \
kube-scheduler-client-csr.json | cfssljson -bare kube-scheduler-client

# KCM
cfssl gencert \
-ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-profile=client \
kube-controller-manager-client-csr.json | cfssljson -bare kube-controller-manager-client

# Kube-proxy
cfssl gencert \
-ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-profile=client \
kube-proxy-client-csr.json | cfssljson -bare kube-proxy-client


# Kubelet
cfssl gencert \
-ca=ca.pem \
-ca-key=ca-key.pem \
-config=ca-config.json \
-profile=client \
kubelet-client-csr.json | cfssljson -bare kubelet-client

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


# Gen kubeconfig file for the admin users
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


# Gen kubeconfig file for KCM
cat <<EOF> kubeconfig-kcm
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    server: https://${APIURL}
    certificate-authority-data: $(cat ca.pem | base64 | tr -d '\n')
users:
- name: kcm
  user:
    client-certificate-data: $(cat kube-controller-manager-client.pem | base64 | tr -d '\n')
    client-key-data: $(cat kube-controller-manager-client-key.pem | base64 | tr -d '\n')
contexts:
- context:
    cluster: local
    user: kcm
EOF


# Controller manager secret
cat <<EOF> controller-manager-secret.yaml
kind: Secret
apiVersion: v1
metadata:
  name: kube-controller-manager
data:
  ca.crt: $(cat ca.pem | base64 | tr -d '\n')
  service-account.key: $(cat kube-apiserver-server-key.pem | base64 | tr -d '\n')
  kubeconfig: $(cat kubeconfig-kcm | base64 | tr -d '\n')
type: Opaque
EOF



# Gen kubeconfig file for scheduler
cat <<EOF> kubeconfig-scheduler
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    server: https://${APIURL}
    certificate-authority-data: $(cat ca.pem | base64 | tr -d '\n')
users:
- name: scheduler
  user:
    client-certificate-data: $(cat kube-scheduler-client.pem | base64 | tr -d '\n')
    client-key-data: $(cat kube-scheduler-client-key.pem | base64 | tr -d '\n')
contexts:
- context:
    cluster: local
    user: scheduler
EOF


# Controller manager secret
cat <<EOF> scheduler-secret.yaml
kind: Secret
apiVersion: v1
metadata:
  name: kube-scheduler
data:
  ca.crt: $(cat ca.pem | base64 | tr -d '\n')
  kubeconfig: $(cat kubeconfig-scheduler | base64 | tr -d '\n')
type: Opaque
EOF


# Gen kubeconfig file for the kubelets
cat <<EOF> kubeconfig-kubelets
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
    client-certificate-data: $(cat kubelet-client.pem | base64 | tr -d '\n')
    client-key-data: $(cat kubelet-client-key.pem | base64 | tr -d '\n')
contexts:
- context:
    cluster: local
    user: admin
EOF


# Gen kubeconfig file for proxy
cat <<EOF> kubeconfig-proxy
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    server: https://${APIURL}
    certificate-authority-data: $(cat ca.pem | base64 | tr -d '\n')
users:
- name: proxy
  user:
    client-certificate-data: $(cat kube-proxy-client.pem | base64 | tr -d '\n')
    client-key-data: $(cat kube-proxy-client-key.pem | base64 | tr -d '\n')
contexts:
- context:
    cluster: local
    user: proxy
EOF
