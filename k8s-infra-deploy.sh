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

echo "Verifying NGINX NodePort service..."
for NODE_IP in $NODE_IPS; do
  echo -n "Checking http://$NODE_IP:31892 ... "
  if curl -s --max-time 5 http://$NODE_IP:31892 | grep -q "Welcome to nginx"; then
    echo "✅ SUCCESS"
  else
    echo "❌ FAILED"
  fi
done

