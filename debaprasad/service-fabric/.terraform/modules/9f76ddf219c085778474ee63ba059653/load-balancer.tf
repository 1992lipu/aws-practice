resource "aws_alb" "main" {
  name                       = "${var.name}-lb"
  internal                   = false
  security_groups            = ["${aws_security_group.load_balancer.id}"]
  subnets                    = ["${var.public_subnet_ids}"]
  enable_deletion_protection = false

  tags {
    Environment = "${var.ENVIRONMENT}"
  }
}

resource "aws_alb_target_group" "main" {
  name                 = "${var.name}-tg"
  port                 = 19080
  protocol             = "HTTP"
  vpc_id               = "${var.vpc_id}"
  deregistration_delay = 60

  health_check = {
    path              = "/Explorer/index.html"
    interval          = 30
    healthy_threshold = 2
  }

  tags {
    Environment = "${var.ENVIRONMENT}"
  }
}

resource "aws_autoscaling_attachment" "target_grp_asg_attachment" {
  autoscaling_group_name = "${aws_autoscaling_group.main.id}"
  alb_target_group_arn   = "${aws_alb_target_group.main.arn}"
}

resource "aws_alb_listener" "main_http" {
  depends_on        = ["aws_alb_target_group.main"]
  load_balancer_arn = "${aws_alb.main.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.main.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener_rule" "explorer" {
  listener_arn = "${aws_alb_listener.main_http.arn}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${aws_alb_target_group.main.arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["/Explorer/*"]
  }
}
