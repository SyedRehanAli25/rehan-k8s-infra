#!/bin/bash
set -e

# Check required commands
for cmd in terraform ansible-playbook jq curl kubectl; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: $cmd is not installed. Please install it first."
    exit 1
  fi
done

echo "Starting Terraform initialization and apply..."
cd terraform
terraform init
terraform apply -auto-approve

echo "Fetching node IPs from Terraform output..."
NODE_IPS=$(terraform output -json node_ips | jq -r '.[]')

echo "Writing Ansible inventory with node IPs..."
cd ..
cat > ansible/inventory.ini <<EOF
[k8s_nodes]
$NODE_IPS

[k8s_nodes:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF

echo "Running Ansible playbook to configure Kubernetes nodes..."
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

echo "Kubernetes cluster setup complete!"

# Get the IP of the first node (can also be done via kubectl)
MASTER_NODE="${NODE_IPS%%$'\n'*}"
echo "Using master node: $MASTER_NODE"

echo "Setting up kubeconfig to talk to the cluster..."
scp -i ~/.ssh/id_rsa ubuntu@$MASTER_NODE:/home/ubuntu/.kube/config ~/.kube/config

echo "Getting NGINX service details..."
NGINX_SERVICE=$(kubectl get svc -n default -l app=nginx -o json)

# Extract NodePort and use the same node IP as before
NODEPORT=$(echo "$NGINX_SERVICE" | jq -r '.items[0].spec.ports[0].nodePort')

# Use the known IP from earlier
echo "Waiting for NGINX to be ready at http://$MASTER_NODE:$NODEPORT ..."
for i in {1..10}; do
  if curl -4 -s --max-time 5 http://$MASTER_NODE:$NODEPORT | grep -q "Welcome to nginx!"; then
    echo "✅ NGINX is reachable at http://$MASTER_NODE:$NODEPORT"
    exit 0
  else
    echo "⏳ Attempt $i: NGINX not ready yet, retrying in 5 seconds..."
    sleep 5
  fi
done

echo "❌ Final attempt failed. NGINX not reachable at http://$MASTER_NODE:$NODEPORT"
exit 1

