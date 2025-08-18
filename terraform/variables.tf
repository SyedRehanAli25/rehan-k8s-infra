variable "key_name" {
  description = "SSH key pair name to access EC2 instances"
  type        = string
  default     = "my-k8s-key"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.medium"
}

variable "node_count" {
  description = "Number of Kubernetes nodes"
  default     = 2
}

