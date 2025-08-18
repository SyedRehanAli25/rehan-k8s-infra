output "node_ips" {
  description = "Public IPs of Kubernetes nodes"
  value       = aws_instance.k8s_nodes[*].public_ip
}

