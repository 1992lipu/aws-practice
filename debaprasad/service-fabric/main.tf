variable "region" {}

variable "ismaster" {
  default = "No"
}

variable "environment" {
  default = "Dev"
}

variable "awsProfile" {
  default = "default"
}

variable "aws_access_key_id" {
  default = ""
}

variable "aws_secret_access_key" {
  default = ""
}

variable "key_name" {
  default = "soumya"
}

variable "instance_count" {
  default = 3
}

variable "availabilityZones" {
  type = "list"
}

# Account Setup
provider "aws" {
  region     = "${var.region}"
  profile    = "${var.awsProfile}"
  access_key = "${var.aws_access_key_id}"
  secret_key = "${var.aws_secret_access_key}"
  version    = "0.1.4"
}

# dev ecs cluster
module "sf_cluster" {
  source             = "./modules/sf-cluster"
  name               = "soumya-sf"
  region             = "${var.region}"
  ismaster           = "${var.ismaster}"
  vpc_id             = "vpc-d923bda2"
  availability_zones = "${var.availabilityZones}"

  public_subnet_ids = [
    "subnet-69babe34",
    "subnet-ed65cce2",
  ]

  key_name = "${var.key_name}"

  # for load balancer ssl
  min_instance_count     = "${var.instance_count}"
  max_instance_count     = "${var.instance_count * 2}"
  desired_instance_count = "${var.instance_count}"

  ENVIRONMENT = "${var.environment}"
}
