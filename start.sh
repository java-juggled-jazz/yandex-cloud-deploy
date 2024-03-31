#!/bin/bash

# Creating Security Group for both Kubernetes and GitLab.
# Allowing traeffic:
# (1) Incoming allowed on port 443 with protocol tcp from all addresses
# (2) Incoming allowed on port 80 with protocol tcp from all addresses
# (3) Incoming allowed on all ports with all protocols from self
# (4) Incoming allowed on all ports with any protocols from addresses 10.96.0.0/16 and 10.112.0.0/16
# (5) Incoming allowed on all ports with protocol tcp from addresses 198.18.235.0/24 and 198.18.248.0/24
# (6) Outgoing allowed on all ports with any protocols from all addresses
# (7) Incoming allowed ICMP-protocol from addresses 10.0.0.0/8, 192.168.0.0/16 and 172.16.0.0/12
yc vpc security-group create --name gitops-sg --network-name default \
  --rule 'direction=ingress,port=443,protocol=tcp,v4-cidrs=0.0.0.0/0' \
  --rule 'direction=ingress,port=80,protocol=tcp,v4-cidrs=0.0.0.0/0' \
  --rule 'direction=ingress,from-port=0,to-port=65535,protocol=any,predefined=self_security_group' \
  --rule 'direction=ingress,from-port=0,to-port=65535,protocol=any,v4-cidrs=[10.96.0.0/16,10.112.0.0/16]' \
  --rule 'direction=ingress,from-port=0,to-port=65535,protocol=tcp,v4-cidrs=[198.18.235.0/24,198.18.248.0/24]' \
  --rule 'direction=egress,from-port=0,to-port=65535,protocol=any,v4-cidrs=0.0.0.0/0' \
  --rule 'direction=ingress,protocol=icmp,v4-cidrs=[10.0.0.0/8,192.168.0.0/16,172.16.0.0/12]'

# Saving Security Group ID in environment variable
export SG_ID=$(yc vpc gitops-sg get --name yc-security-group | head -1 | awk '{print $2}')

# Creating Yandex Cloud Service Account
yc iam service-account create kube-infra

# Setting Service Account editor role
yc resource-manager folder add-access-binding \
  --name=default \
  --service-account-name=kube-infra \
  --role=editor

# Creating Managed Kubernetes Cluster
yc managed-kubernetes cluster create \
  --name=kube-infra \
  --public-ip \
  --network-name=default \
  --service-account-name=kube-infra \
  --node-service-account-name=kube-infra \
  --release-channel=rapid \
  --zone=ru-central1-b \
  --version 1.24 \
  --security-group-ids=$SG_ID \
  --folder-name default

# Creating Working Group
yc managed-kubernetes node-group create \
  --name=group-1 \
  --cluster-name=kube-infra \
  --cores=2 \
  --memory=4G \
  --preemptible \
  --auto-scale=initial=1,min=1,max=2 \
  --network-interface=subnets=default-ru-central1-b,ipv4-address=nat,security-group-ids=<id созданной группы безопасности> \
  --folder-name default \
  --metadata="ssh-keys=$KUBE_USERNAME:$SSH_PUB_KEY"

# Obtaining Kubeconfig
yc managed-kubernetes cluster get-credentials --name=kube-infra --external

# 
