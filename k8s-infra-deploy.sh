#!/bin/bash
set -e

# Check for required commands
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

# Optional: Check if nginx is accessible on the first node
NODE_PORT=31892
FIRST_NODE_IP=$(echo "$NODE_IPS" | head -n1)

echo "Checking nginx on http://$FIRST_NODE_IP:$NODE_PORT ..."
if curl -s --max-time 5 "http://$FIRST_NODE_IP:$NODE_PORT" | grep -q "Welcome to nginx"; then
  echo "Nginx is up and serving content on $FIRST_NODE_IP:$NODE_PORT"
else
  echo "Warning: Could not verify nginx on $FIRST_NODE_IP:$NODE_PORT"
fi

