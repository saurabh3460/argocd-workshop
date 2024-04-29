setup-multi-cluster:
	kind create cluster --name cluster-1
	kind create cluster --name cluster-2
	kubectx kind-cluster-2
	kubectl patch svc kubernetes -n default -p '{"spec": {"type": "NodePort"}}'

# This target updates the 'server' parameter in the kubeconfig file of an external cluster.
# It retrieves the internal IP address of a node and the NodePort of the 'kubernetes' service,
# then uses them to construct the server address for the cluster.
update-kubeconfig-address:
	kubectl config set-cluster k3d-cluster-2 \
  	--server=https://$(shell kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'):$(shell kubectl get svc kubernetes -n default -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
	
setup-argocd:
	kubectx kind-cluster-1
	kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f ./argocd-install.yaml
	kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

setup-argocd-cli:
# This target need fixes
	kubectx kind-cluster-1
	kubectl wait --for=condition=available  deploy/argocd-server --timeout=300s -n argocd
# kill $(shell lsof -ti:8080)
	kubectl port-forward svc/argocd-server -n argocd 8080:443 &
	sleep 2
	argocd login \
		--username admin \
		--password $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo) \
		localhost:8080 \
		--insecure \

add-cluster:
	argocd cluster add kind-cluster-2 -y

get-argocd-endpoint:
	@echo "http://$(shell kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

get-argocd-password:
	@echo "$(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)"

destroy-multi-cluster:
	kind delete clusters cluster-1 cluster-2

destroy-argocd:
	kubectl delete -n argocd -f ./argocd-install.yaml