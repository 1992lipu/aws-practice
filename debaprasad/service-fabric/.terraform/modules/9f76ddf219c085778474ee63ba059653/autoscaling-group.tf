resource "aws_autoscaling_group" "main" {
  launch_configuration      = "${aws_launch_configuration.main.name}"
  availability_zones        = "${var.availability_zones}"
  vpc_zone_identifier       = ["${var.public_subnet_ids}"]
  name                      = "${var.name}-ecs-scaling-group"
  desired_capacity          = "${var.desired_instance_count}"
  min_size                  = "${var.min_instance_count}"
  max_size                  = "${var.max_instance_count}"
  health_check_type         = "EC2"
  health_check_grace_period = 0
  default_cooldown          = 30
  force_delete              = true
  termination_policies      = ["OldestInstance"]

  tag {
    key                 = "Name"
    value               = "${var.name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "IsServiceFabricMaster"
    value               = "${var.ismaster}"
    propagate_at_launch = true
  }
}

resource "aws_cloudwatch_metric_alarm" "scale_up" {
  alarm_name          = "aws_autoscaling_group_scale_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.main.name}"
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.scale_up_policy.arn}"]
}

resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "aws_autoscaling_group_scale_up_policy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.main.name}"
}

resource "aws_cloudwatch_metric_alarm" "scale_down" {
  alarm_name          = "aws_autoscaling_group_scale_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"

  dimensions {
    AutoScalingGroupName = "${aws_autoscaling_group.main.name}"
  }

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = ["${aws_autoscaling_policy.scale_down_policy.arn}"]
}

resource "aws_autoscaling_policy" "scale_down_policy" {
  name                   = "aws_autoscaling_group_scale_down_policy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = "${aws_autoscaling_group.main.name}"
}
