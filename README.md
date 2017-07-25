# k8s-on-k8s

This is a *WIP* I work on in my spare time to make k8s _control plane as a service_ so
I can easily test new versions and various networking drivers.


Theory of operation
--------------

A _master_ or _infrastructure_ cluster provides control plane as a service to multiple
cluster administrators by granting each of them writable access to a namespace.

The control plane is provisioned in that namespace just like any common containerized
application using deployments, services and ingress native objects.

The cluster administrator can then connect his worker nodes to that control plane
and create the necessary RBAC bindings for his consumers with no change to the
infrastructure cluster.

A basic script creates the control plane for now but later a CRD will define the desired
control plane and an operator will do the heavy lifting.


Current state
--------------
Just a WIP... a lot remain to be done.  For now you get a remote API server backed
by a single etcd member and a kubeconfig file with admin privileges.      


Short term TODO:
* Add KCM/Scheduler to control plane assets
* Connect a remote kubelet/kube-proxy
* Add kube-dns
* Find a way to make in-cluster client use the API server


Requirements
--------------
* cfssl
* kubectl
* Access to a writable namespace on the infra cluster


Sample usage in the current POC state.  Specify the desired API URL hostname that
must resolve and get to the infrastructure cluster ingress controller
(can be as easy as a CNAME to that ingress controller or an A record to its IP)


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
secret "kube-apiserver" created
secret "admin-kubeconfig" created
deployment "etcd" created
service "etcd0" created
deployment "kube-apiserver" created
ingress "k8s-on-k8s" created
service "apiserver" created
Giving a few seconds for the API server to start...
Client Version: version.Info{Major:"1", Minor:"7", GitVersion:"v1.7.1", GitCommit:"1dc5c66f5dd61da08412a74221ecc79208c2165b", GitTreeState:"clean", BuildDate:"2017-07-14T02:00:46Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"7", GitVersion:"v1.7.2", GitCommit:"922a86cfcd65915a9b2f69f3f193b8907d741d9c", GitTreeState:"clean", BuildDate:"2017-07-21T08:08:00Z", GoVersion:"go1.8.3", Compiler:"gc", Platform:"linux/amd64"}
```


Clean up
--------------
```
kubectl -n namespaceX delete deployment,svc,secrets,ingress --all
```
