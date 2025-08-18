#  rehan-k8s-infra

This project automates the provisioning of a Kubernetes cluster on AWS EC2 instances using **Terraform** and **Ansible**, and deploys an NGINX web server to validate the setup.

---

## Project Structure

k8s-infra/
├── terraform/ # Infrastructure provisioning using Terraform
│ ├── main.tf
│ ├── provider.tf
│ ├── variables.tf
│ ├── output.tf
│ └── security_group_rules.tf
├── ansible/ # Cluster configuration using Ansible
│ ├── inventory.ini # Auto-generated during deployment
│ └── playbook.yml # Installs Kubernetes, Docker, kubeadm, etc.
├── k8s-infra-deploy.sh # End-to-end deployment script

---

## Features

-  Provision EC2 instances on AWS (Ubuntu)
-  Configure Kubernetes cluster (via kubeadm)
-  Deploy NGINX using Kubernetes
-  Auto-detect working node and validate NGINX via curl
-  Single-click script to deploy everything

---

## rerequisites

Make sure the following tools are installed on your machine:

- [Terraform](https://developer.hashicorp.com/terraform/install)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- [jq](https://stedolan.github.io/jq/)
- [ssh-agent](https://linux.die.net/man/1/ssh-agent) + SSH key access to AWS instances

---

## Usage

1. **Clone the repository**:

   git clone https://github.com/SyedRehanAli25/rehan-k8s-infra.git
   cd rehan-k8s-infra
Make the deploy script executable:

chmod +x k8s-infra-deploy.sh
Run the deployment:

./k8s-infra-deploy.sh
This will:

Provision EC2 instances using Terraform

Generate the Ansible inventory

Configure Kubernetes with Ansible

Deploy NGINX

Detect which node serves NGINX

Verify external accessibility

Output Example
If successful, you'll see:

NGINX is reachable at http://54.219.103.231:30590 
Open it in your browser and you should see the "Welcome to nginx!" page.

Notes
Instances are created with public IPs and SSH access (port 22 must be open).

NGINX is exposed via a Kubernetes NodePort service.

This is intended for learning, not production.

