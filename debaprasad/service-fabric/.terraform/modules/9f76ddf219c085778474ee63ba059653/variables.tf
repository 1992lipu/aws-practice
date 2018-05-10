variable "region" {}

variable "name" {}

variable "project" {
  default = "ns-test"
}

# The route53 elb health check interval for region fail over.
# The value 30s interval will have a downtime of 2mins based on actual test results. 
# In prod set this to fast interval (10s) with lower downtime of 60s limited by DNS TTL.
# Additional cost apply for fast interval, see pricing: https://aws.amazon.com/route53/pricing/
variable "route53_healthcheck_interval" {
  default = "30"
}

# networking config - where the cluster instances will live
variable "vpc_id" {}

variable "availability_zones" {
  default = []
}

# for load balancer
variable "public_subnet_ids" {
  default = []
}

# for launch configuration
variable "key_name" {}

variable "instance_type" {
  default = "t2.medium"
}

# for autoscaling group
variable "min_instance_count" {
  default = 1
}

variable "max_instance_count" {
  default = 2
}

variable "desired_instance_count" {
  default = 1
}

variable "ismaster" {}

variable "ENVIRONMENT" {}
