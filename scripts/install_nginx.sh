echo "---- Kubernetes Node State ----"
kubectl get nodes
kubectl cluster-info

cd ~/application/

echo "---- Create deployment ----"
kubectl apply -f deployment.yaml

kubectl get deployments
kubectl get pods -o wide
