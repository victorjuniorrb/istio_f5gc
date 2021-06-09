# Makefile

NAMESPACE=free5gc
ISTIO_VERSION=1.9.1
ISTIO_DIR=/tmp/istio-${ISTIO_VERSION}

.PHONY: help

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help


install-istiod: istioctl ## Instalar istiod, istio-ingressgateway e istio-egressgateway
	cd ${ISTIO_DIR}
	istioctl install --set profile=demo -y
	kubectl apply -f ${ISTIO_DIR}/samples/addons/ || true
	kubectl apply -f ${ISTIO_DIR}/samples/addons/ || true
	kubectl create namespace ${NAMESPACE}
	kubectl label namespace default ${NAMESPACE} istio-injection=enabled
#	addicionar certificados
	sh ./monitoring/build_ssl.sh
	kubectl create -n istio-system secret tls monitoring-gw-cert --key=cert/tls.key --cert=cert/tls.crt
#	gateway para grafana, kiali, prometheus e tracing
	kubectl apply -f monitoring/

uninstall-istiod: ## Remover istiod, istio-ingressgateway e istio-egressgateway
	kubectl delete -f ${ISTIO_DIR}/samples/addons/ || true
	istioctl manifest generate --set profile=demo | kubectl delete --ignore-not-found=true -f -
	kubectl delete namespace istio-system
	kubectl label namespace default istio-injection-
	sudo rm /usr/local/bin/istioctl

istioctl: ## Instalar istioctl em /usr/local/bin
	cd /tmp && curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.9.1 TARGET_ARCH=x86_64 sh - && \
	sudo cp istio-${ISTIO_VERSION}/bin/istioctl /usr/local/bin

install-metallb: ## network load-balancer
# set strictARP
	kubectl get configmap kube-proxy -n kube-system -o yaml | \
	sed -e "s/strictARP: false/strictARP: true/" | \
	kubectl apply -f - -n kube-system || true
# Instalar via Manifest
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/namespace.yaml
	kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/metallb.yaml
# Na primeira instalacao
	kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
# Definir deploy e configmap
	kubectl apply -f k8s/metallb.yaml

uninstall-metallb:
	kubectl delete -f k8s/metallb.yaml
	kubectl -n metallb-system delete secrets memberlist 
	kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/metallb.yaml
	kubectl delete -f https://raw.githubusercontent.com/metallb/metallb/v0.9.6/manifests/namespace.yaml

	kubectl get configmap kube-proxy -n kube-system -o yaml | \
	sed -e "s/strictARP: true/strictARP: false/" | \
	kubectl apply -f - -n kube-system || true
	