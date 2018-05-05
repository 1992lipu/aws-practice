data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user-data.tpl")}"
}

data "aws_ami" "amaz-ami-windows_server" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Windows_Server-2016-English-Full-Containers-*"]
  }

  owners = ["amazon"]
}

resource "aws_launch_configuration" "main" {
  name_prefix                 = "${var.name}-ecs-launch-config-"
  image_id                    = "${data.aws_ami.amaz-ami-windows_server.image_id}"
  instance_type               = "${var.instance_type}"
  associate_public_ip_address = false

  key_name             = "soumya"
  iam_instance_profile = "ecsInstanceRole-1"
  security_groups      = ["${aws_security_group.instances.id}"]
  user_data            = "${data.template_file.user_data.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}
