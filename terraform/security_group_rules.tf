# NodePort (NGINX) access
resource "aws_security_group_rule" "allow_nodeport" {
  type              = "ingress"
  from_port         = 30000
  to_port           = 32767
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_sg.id
  description       = "Allow NodePort services (e.g., NGINX)"
}

# BGP from Node 1
resource "aws_security_group_rule" "allow_bgp_node1" {
  type              = "ingress"
  from_port         = 179
  to_port           = 179
  protocol          = "tcp"
  cidr_blocks       = ["172.31.16.140/32"]
  security_group_id = aws_security_group.k8s_sg.id
  description       = "BGP (from Node 1)"
}

# BGP from Node 2
resource "aws_security_group_rule" "allow_bgp_node2" {
  type              = "ingress"
  from_port         = 179
  to_port           = 179
  protocol          = "tcp"
  cidr_blocks       = ["172.31.21.190/32"]
  security_group_id = aws_security_group.k8s_sg.id
  description       = "BGP (from Node 2)"
}

