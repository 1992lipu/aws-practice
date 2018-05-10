/* load balancer group and rules */

resource "aws_security_group" "load_balancer" {
  vpc_id      = "${var.vpc_id}"
  name        = "${var.name}-LoadBalancerSecurityGroup"
  description = "${var.name}-LoadBalancerSecurityGroup"

  tags {
    Name = "${var.name}-LoadBalancerSecurityGroup"
  }
}

# incoming rules for the load balancer

resource "aws_security_group_rule" "anywhere_to_load_balancer_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.load_balancer.id}"
}

resource "aws_security_group_rule" "anywhere_to_load_balancer_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.load_balancer.id}"
}

# outbound rules from the load balancer to the instances

resource "aws_security_group_rule" "load_balancer_to_instances" {
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.load_balancer.id}"
  source_security_group_id = "${aws_security_group.instances.id}"
}

/* instances group and rules */

resource "aws_security_group" "instances" {
  vpc_id      = "${var.vpc_id}"
  name        = "${var.name}-InstanceSecurityGroup"
  description = "${var.name}-InstanceSecurityGroup"

  tags {
    Name = "${var.name}-InstanceSecurityGroup"
  }
}

# incoming rules from the load balancer to the instances

resource "aws_security_group_rule" "instances_from_load_balancer" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.instances.id}"
  source_security_group_id = "${aws_security_group.load_balancer.id}"
}

resource "aws_security_group_rule" "rdp_ipreo_cidr" {
  type                     = "ingress"
  from_port                = 3389
  to_port                  = 3389
  protocol                 = "tcp"
  cidr_blocks     		   = ["10.11.0.0/16","10.16.0.0/16"]
  security_group_id        = "${aws_security_group.instances.id}"
}
resource "aws_security_group_rule" "http_ingress" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  cidr_blocks     		   = ["0.0.0.0/0"]
  security_group_id        = "${aws_security_group.instances.id}"
}

resource "aws_security_group_rule" "https_ingress" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  cidr_blocks     		   = ["0.0.0.0/0"]
  security_group_id        = "${aws_security_group.instances.id}"
}
resource "aws_security_group_rule" "privateNetwork_ingress" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  cidr_blocks     		   = ["10.159.0.0/23","10.159.2.0/23"]
  security_group_id        = "${aws_security_group.instances.id}"
}
resource "aws_security_group_rule" "icmp_ingress" {
  type                     = "ingress"
  from_port                = 8
  to_port                  = -1
  protocol                 = "icmp"
  cidr_blocks     		   = ["10.159.0.0/23","10.159.2.0/23"]
  security_group_id        = "${aws_security_group.instances.id}"
}

# outbound rules from the instances to "anyhere"... 
# note these will be routed through the transit VPC for internet locations

resource "aws_security_group_rule" "instances_to_anywhere" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.instances.id}"
}
