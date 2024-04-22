setup-multi-cluster:
	k3d cluster create cluster-1 --k3s-arg "--disable=traefik@server:*" 
	k3d cluster create cluster-2 --k3s-arg "--disable=traefik@server:*"
	kubectx k3d-cluster-2
	kubectl patch svc kubernetes -n default -p '{"spec": {"type": "NodePort"}}'

# This target updates the 'server' parameter in the kubeconfig file of an external cluster.
# It retrieves the internal IP address of a node and the NodePort of the 'kubernetes' service,
# then uses them to construct the server address for the cluster.
update-kubeconfig-address:
	kubectl config set-cluster k3d-cluster-2 \
  	--server=https://$(shell kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'):$(shell kubectl get svc kubernetes -n default -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
	
setup-argocd:
	kubectx k3d-cluster-1
	kubectl create ns argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f ./argocd-install.yaml
	kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

setup-argocd-cli:
	argocd login \
		--username admin \
		--password $(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo) \
		$(shell kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}') \
		--insecure 

add-cluster:
	argocd cluster add k3d-cluster-2 -y

get-argocd-endpoint:
	@echo "http://$(shell kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

get-argocd-password:
	@echo "$(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)"

destroy-multi-cluster:
	k3d cluster delete cluster-1
	k3d cluster delete cluster-2

destroy-argocd:
	kubectl delete -n argocd -f ./argocd-install.yaml