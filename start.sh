#!/bin/bash

# Creating directory for outputs
mkdir -p outputs

# Creating directory for charts
mkdir -p charts

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

# Creating Yandex Cloud Service Account
yc iam service-account create --name ingress-controller

# Role alb.editor is requried to create load-balancers
yc resource-manager folder add-access-binding default \
--service-account-name=ingress-controller \
--role alb.editor

# Role vpc.publicAdmin is required to manage external addresses
yc resource-manager folder add-access-binding default \
--service-account-name=ingress-controller \
--role vpc.publicAdmin

# Role certificate-manager.certificates.downloader
# is required to download certificates from Yandex Certificate Manager
yc resource-manager folder add-access-binding default \
--service-account-name=ingress-controller \
--role certificate-manager.certificates.downloader

# Role compute.viewer is required to add node into the balancer
yc resource-manager folder add-access-binding default \
--service-account-name=ingress-controller \
--role compute.viewer

# Creating Authorization Key
yc iam key create --service-account-name ingress-controller --output outputs/sa-key.json

# Authorization Yandex Helm Registry
export HELM_EXPERIMENTAL_OCI=1
cat outputs/sa-key.json | helm registry login cr.yandex --username 'json_key' --password-stdin

# Downloading Ingress Controller Helm into the "charts" directory
helm pull oci://cr.yandex/yc-marketplace/yandex-cloud/yc-alb-ingress/yc-alb-ingress-controller-chart \
  --version v0.1.17 --untar --untardir=charts

# Installing the Chart into the Cluster
export FOLDER_ID=$(yc config get folder-id)
export CLUSTER_ID=$(yc managed-kubernetes cluster get kube-infra | head -n 1 | awk -F ': ' '{print $2}')

helm install \
--create-namespace \
--namespace yc-alb-ingress \
--set folderId=$FOLDER_ID \
--set clusterId=$CLUSTER_ID \
--set-file saKeySecretKey=sa-key.json \
yc-alb-ingress-controller ./charts/yc-alb-ingress-controller-chart/

# Checking if resources are created
kubectl -n yc-alb-ingress get all

# Creating Namespace
kubectl create namespace httpbin

# Applying the Manifest to created Namespace
kubectl apply -n httpbin -f manifests/httpbin.yaml


