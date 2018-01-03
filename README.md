# k8s-on-k8s

This project aims to build k8s _control planes_ on demand using an existing k8s
cluster so you can easily test new versions, features or networking drivers without
having to wait for an installer to support it.

It can also be used for teaching purposes giving every student a control plane
using as little resources as what a few _hyperkube_ and _etcd_ PODs consume.


Theory of operation
--------------

A _master_ or _infrastructure_ cluster provides control plane as a service to multiple
delegated cluster administrators by granting each of them a writable namespace.

The Kubernetes _hosted_ control plane is provisioned in that namespace just like any
common containerized application using deployments, services and ingress native objects.

The cluster administrator can then connect his worker nodes to that control plane
and create the necessary RBAC bindings for his consumers with no change to the
infrastructure cluster.

A basic script creates the control plane in a *kubeadm* compatible way, in the sense
you can use kubeadm to manage tokens for workers to join

![In a picture](docs/k8sonk8s.png)


Current state
--------------
It's a WIP.
* A single etcd member with no persistence (until setup with operator)  
* A k8s control plane with RBAC enabled (API server, controller-manager and scheduler)
* Kubeconfig files for the hosted cluster administrator
* Flannel and kube-proxy daemon-sets to be instantiated on workers
* Kube-dns on the first worker joining the cluster

Also note this _10.199.199.199_ IP advertised in the API server manifest and setup
locally on each worker's loopback interface as show below.  This is a work around for in-cluster
clients using the built-in kubernetes service to reach the API server (such as kube-flannel
and kube-dns PODs) via a nodePort service.


Local requirements to deploy _hosted_ control planes
--------------
* cfssl
* kubectl setup with the infrastructure cluster context


K8s Infrastructure requirements
--------------
* Access to a writable namespace
* A functional ingress controller on the infra cluster


Creating the hosted control plane
--------------
Specify the desired API URL hostname that must resolve and route to the infrastructure
cluster's ingress controller. This could be as a CNAME to the ingress controller
of the infrastructure cluster.


```
$ ./deploy.sh -h kubernetes.foo-bar.com -n namespaceX
CHECK: Access to cluster confirmed
CHECK: API server host kubernetes.foo-bar.com resolves
2017/07/25 08:31:46 [INFO] generating a new CA key and certificate from CSR
2017/07/25 08:31:46 [INFO] generate received request
2017/07/25 08:31:46 [INFO] received CSR
2017/07/25 08:31:46 [INFO] generating key: rsa-2048
2017/07/25 08:31:46 [INFO] encoded CSR
2017/07/25 08:31:46 [INFO] signed certificate with serial number 343368285204006686908415438394591991039302384146
2017/07/25 08:31:46 [INFO] generate received request
2017/07/25 08:31:46 [INFO] received CSR
2017/07/25 08:31:46 [INFO] generating key: rsa-2048
2017/07/25 08:31:47 [INFO] encoded CSR
2017/07/25 08:31:47 [INFO] signed certificate with serial number 634677056508179731833979679679719784750411028857
2017/07/25 08:31:47 [INFO] generate received request
2017/07/25 08:31:47 [INFO] received CSR
2017/07/25 08:31:47 [INFO] generating key: rsa-2048
2017/07/25 08:31:47 [INFO] encoded CSR
2017/07/25 08:31:47 [INFO] signed certificate with serial number 34772891780328732259434788313932796585661614421
...
secret "kube-apiserver" created
secret "admin-kubeconfig" created
secret "kube-controller-manager" created
secret "kube-scheduler" created
deployment "etcd" created
service "etcd0" created
deployment "kube-apiserver" created
ingress "k8s-on-k8s" created
service "apiserver" created
deployment "kube-controller-manager" created
deployment "kube-scheduler" created
Giving a few seconds for the API server to start...
Trying to connect to the hosted control plane...
......AVAILABLE !
Client Version: version.Info{Major:"1", Minor:"7", GitVersion:"v1.7.1", GitCommit:"1dc5c66f5dd61da08412a74221ecc79208c2165b", GitTreeState:"clean", BuildDate:"2017-07-14T02:00:46Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"9", GitVersion:"v1.9.0", GitCommit:"925c127ec6b946659ad0fd596fa959be43f0cc05", GitTreeState:"clean", BuildDate:"2017-12-15T20:55:30Z", GoVersion:"go1.9.2", Compiler:"gc", Platform:"linux/amd64"}
Deploying child cluster assets
secret "kubeconfig-proxy" created
daemonset "kube-proxy" created
clusterrole "flannel" created
clusterrolebinding "flannel" created
serviceaccount "flannel" created
configmap "kube-flannel-cfg" created
daemonset "kube-flannel-ds" created
configmap "kube-dns" created
deployment "kube-dns" created
serviceaccount "kube-dns" created
service "kube-dns" created
```


Prepare the control plane for kubelet bootstraping
--------------
```
docker run -v ${PWD}/tls:/tmp/tls -it jfnadeau/kubeadm:1.9.0 kubeadm alpha phase bootstrap-token cluster-info --kubeconfig /tmp/tls/kubeconfig
docker run -v ${PWD}/tls:/tmp/tls -it jfnadeau/kubeadm:1.9.0 kubeadm alpha phase bootstrap-token node allow-auto-approve --kubeconfig /tmp/tls/kubeconfig
docker run -v ${PWD}/tls:/tmp/tls -it jfnadeau/kubeadm:1.9.0 kubeadm alpha phase bootstrap-token node allow-post-csrs --kubeconfig /tmp/tls/kubeconfig
docker run -v ${PWD}/tls:/tmp/tls -it jfnadeau/kubeadm:1.9.0 kubeadm token create --kubeconfig /tmp/tls/kubeconfig
5a5312.564acf6a9824ca38    <--- Use this on the workers
```

Connecting a worker
--------------

Follow the kubeadm installation process for your OS as described https://kubernetes.io/docs/setup/independent/install-kubeadm/

```
kubeadm join --token 5a5312.564acf6a9824ca38 <master-ip>:443 --discovery-token-unsafe-skip-ca-verification
```



Using the _hosted_ cluster resources
--------------

A _kubeconfig_ file with admin privileges was created under the tls directory.

Use it to perform administrator tasks and to create the additional
RBAC bindings for the end user (if any but you !)


```
$ kubectl get nodes --kubeconfig=tls/kubeconfig
NAME      STATUS    AGE       VERSION
node1     Ready     12m       v1.9.0
```

```
$ kubectl --kubeconfig=tls/kubeconfig get pods -n kube-system -o wide
NAME                        READY     STATUS    RESTARTS   AGE       IP              NODE
kube-dns-2177165803-19jgj   3/3       Running   0          3m        10.2.0.2        192.168.1.125
kube-flannel-ds-29nwm       2/2       Running   1          3m        192.168.1.124   192.168.1.124
kube-flannel-ds-btlg7       2/2       Running   1          3m        192.168.1.125   192.168.1.125
kube-proxy-fz6s5            1/1       Running   0          3m        192.168.1.125   192.168.1.125
kube-proxy-jtfk4            1/1       Running   0          3m        192.168.1.124   192.168.1.124

```


Delete hosted k8s resources
--------------
```
kubectl -n namespaceX delete deployment,svc,secrets,ingress --all
```
