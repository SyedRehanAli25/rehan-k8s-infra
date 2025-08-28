#!/bin/bash
set -e

# Ensure required commands exist
for cmd in terraform ansible-playbook jq curl ssh; do
  if ! command -v $cmd &> /dev/null; then
    echo "Error: $cmd is not installed. Please install it first."
    exit 1
  fi
done

echo "Starting Terraform initialization and apply..."
cd terraform
rm -rf .terraform
rm -f terraform.tfstate terraform.tfstate.backup
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

MASTER_NODE_IP="${PUBLIC_IPS[0]}"

# Get NodePort by SSH-ing to the master node using ssh-agent auth (no key file path)
NODEPORT=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes -l ubuntu $MASTER_NODE_IP \
"KUBECONFIG=/home/ubuntu/.kube/config kubectl get svc -n default -l app=nginx -o jsonpath='{.items[0].spec.ports[0].nodePort}'")

if [ -z "$NODEPORT" ]; then
  echo "Could not retrieve NodePort for NGINX"
  exit 1
fi

echo "Discovered NodePort: $NODEPORT"
echo "Checking which node is serving NGINX..."

for IP in "${PUBLIC_IPS[@]}"; do
  echo "Testing http://$IP:$NODEPORT from remote node..."
  if ssh -o StrictHostKeyChecking=no -o BatchMode=yes -l ubuntu $IP \
    "curl -s --max-time 5 http://localhost:$NODEPORT" | grep -q "Welcome to nginx"; then
    echo "NGINX is reachable at http://$IP:$NODEPORT"
    exit 0
  else
    echo "$IP is not serving NGINX, trying next..."
  fi
done

echo "NGINX is not reachable on any public IPs with NodePort $NODEPORT"
exit 1

