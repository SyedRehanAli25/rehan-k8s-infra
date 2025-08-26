#!/bin/bash
set -e

# Ensure required paths are available (especially for Jenkins)
export PATH="/usr/bin:/usr/local/bin:$PATH"

# Debug PATH to verify environment in Jenkins
echo "PATH is: $PATH"
which terraform

# Check required commands
for cmd in terraform ansible-playbook jq curl; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: $cmd is not installed. Please install it first."
    exit 1
  fi
done

echo "Starting Terraform initialization and apply..."
cd terraform
rm -rf .terraform
rm -f terraform.tfstate
rm -f terraform.tfstate.backup
terraform init -input=false
terraform apply -auto-approve

echo "Fetching node IPs from Terraform output..."
NODE_IPS=$(terraform output -json node_ips | jq -r '.[]')
cd ..

echo "Writing Ansible inventory with node IPs..."
cat > ansible/inventory.ini <<EOF
[k8s_nodes]
$NODE_IPS

[k8s_nodes:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
EOF

echo "Running Ansible playbook to configure Kubernetes nodes..."
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

echo "Kubernetes cluster setup complete!"

echo "Fetching public node IPs from Terraform..."
cd terraform
PUBLIC_IPS=($(terraform output -json node_ips | jq -r '.[]'))
cd ..

# Use the first node (master) to get the NodePort value
MASTER_NODE_IP="${PUBLIC_IPS[0]}"
NODEPORT=$(ssh -o StrictHostKeyChecking=no -i /var/lib/jenkins/.ssh/id_rsa ubuntu@$MASTER_NODE_IP \
  "kubectl get svc -n default -l app=nginx -o jsonpath='{.items[0].spec.ports[0].nodePort}'")

if [ -z "$NODEPORT" ]; then
  echo " Could not retrieve NodePort for NGINX"
  exit 1
fi

echo " Discovered NodePort: $NODEPORT"
echo "Checking which node is serving NGINX..."
# Loop through public IPs and test the NodePort remotely
for IP in "${PUBLIC_IPS[@]}"; do
  echo "Testing http://$IP:$NODEPORT from remote node..."
  if ssh -o StrictHostKeyChecking=no -i /var/lib/jenkins/.ssh/id_rsa ubuntu@$IP \
    "curl -s --max-time 5 http://localhost:$NODEPORT" | grep -q "Welcome to nginx"; then
    echo " NGINX is reachable at http://$IP:$NODEPORT"
    exit 0
  else
    echo " $IP is not serving NGINX, trying next..."
  fi
done

echo " NGINX is not reachable on any public IPs with NodePort $NODEPORT"
exit 1


