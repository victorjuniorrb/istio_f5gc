#!/bin/bash

# Download
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.9.1 TARGET_ARCH=x86_64 sh -
cd istio-1.9.1

# nome do namespace
export NAMESPACE=free5gc
export PATH=$PWD/bin:$PATH

# Instalar Metallb para resolver problema de EXTERNAL-IP no serviço istio-ingressgateway
#../build_metallb.sh

# Install
istioctl install --set profile=demo -y

# instalar addons como grafana, kiali, prometheus
kubectl apply -f samples/addons

# criar namespace
kubectl create namespace $NAMESPACE

# Adicionar sidecar proxy automáticamente em cada pod no namespace
kubectl label namespace default $NAMESPACE istio-injection=enabled