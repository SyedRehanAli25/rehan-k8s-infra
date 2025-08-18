#!/bin/bash
set -e

# Check required commands
for cmd in terraform ansible-playbook jq curl; do
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

# Extract first node IP to test NGINX NodePort service
FIRST_NODE_IP=$(echo "$NODE_IPS" | head -n1)
NODEPORT=31892

echo "Verifying NGINX NodePort service on http://$FIRST_NODE_IP:$NODEPORT ..."
if curl -s --max-time 10 http://$FIRST_NODE_IP:$NODEPORT | grep -q "Welcome to nginx!"; then
  echo "✅ NGINX is reachable at http://$FIRST_NODE_IP:$NODEPORT"
else
  echo "❌ Failed to reach NGINX at http://$FIRST_NODE_IP:$NODEPORT"
fi

