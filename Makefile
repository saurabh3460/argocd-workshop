setup-multi-cluster:
	k3d cluster create cluster-1 --k3s-arg "--disable=traefik@server:*" 
	k3d cluster create cluster-2 --k3s-arg "--disable=traefik@server:*"

setup-argocd:
	kubectx k3d-cluster-1
	kubectl create namespace argocd
	kubectl apply -n argocd -f ./argocd-install.yaml
	kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

get-argocd-endpoint:
	@echo "http://$(shell kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

get-argocd-password:
	@echo "$(shell kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)"

destroy-multi-cluster:
	k3d cluster delete cluster-1
	k3d cluster delete cluster-2



