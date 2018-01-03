FROM debian:stretch-slim

ENV version 1.9.0-00

RUN apt-get update \
 && apt-get install -y apt-transport-https gnupg curl \
 && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg > /tmp/key.gpg \
 && apt-key add /tmp/key.gpg \
 && echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list \
 && apt-get update \
 && alias systemctl=/bin/true \
 && apt-get install -y kubelet=${version} kubeadm=${version} kubectl=${version}  --allow-unauthenticated ; exit 0

CMD ["/bin/sh"]
