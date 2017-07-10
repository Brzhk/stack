variable "name" {
  description = "ELB name, e.g cdn"
  default     = "jenkins"
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs"
}

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "http_port" {
  description = "Instance port for HTTP service"
}

variable "jnlp_port" {
  description = "Instance port for JNLP Slave connection"
}

variable "vpc_id" {
  description = "The VPC ID"
}

variable "cidr" {
  description = "The cidr block to use for internal security groups"
}

variable "elb_jnlp_port" {
  description = "Instance port for JNLP Slave connection"
}

variable "internal_elb_security_group_id" {
  description = "the internal-elb-sg ID"
}

variable "log_bucket" {
  description = "S3 bucket name to write ELB logs into"
}

variable "internal_dns_name" {
  description = "The subdomain under which the ELB is exposed internally, defaults to the task name"
}
variable "internal_zone_id" {
  description = "The zone ID to create the record in"
}


/**
 * Resources.
 */
resource "aws_elb" "internal" {
  name                        = "${var.name}-internal"

  internal                    = true
  cross_zone_load_balancing   = true
  subnets                     = ["${split(",", var.subnet_ids)}"]
  security_groups             = [
    "${var.internal_elb_security_group_id}",
    "${aws_security_group.internal_jnlp_elb.id}"]

  idle_timeout                = 30
  connection_draining         = true  // TODO check if connection draining is pertinent
  connection_draining_timeout = 15

  listener {
    // provided to the ECS JNLP Slaves as endpoint
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "${var.http_port}"
    instance_protocol = "http"
  }

  listener {
    // provided for the JNLP Slaves (also as tunnel)
    lb_port           = "${var.elb_jnlp_port}"
    lb_protocol       = "tcp"
    instance_port     = "${var.jnlp_port}"
    instance_protocol = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    target              = "TCP:${var.http_port}"
    interval            = 30
  }

  access_logs {
    bucket = "${var.log_bucket}"
  }

  tags {
    Name        = "${var.name}-internal-balancer"
    Service     = "${var.name}"
    Environment = "${var.environment}"
  }
}

resource "aws_route53_record" "internal" {
  zone_id = "${var.internal_zone_id}"
  name    = "${var.internal_dns_name}"
  type    = "A"

  alias {
    zone_id                = "${aws_elb.internal.zone_id}"
    name                   = "${aws_elb.internal.dns_name}"
    evaluate_target_health = false
  }
}

resource "aws_security_group" "internal_jnlp_elb" {
  name        = "${format("%s-%s-internal-jnlp-elb", var.name, var.environment)}"
  vpc_id      = "${var.vpc_id}"
  description = "Allows internal ELB traffic"

  ingress {
    from_port   = "${var.elb_jnlp_port}"
    to_port     = "${var.elb_jnlp_port}"
    protocol    = "tcp"
    cidr_blocks = ["${var.cidr}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags {
    Name        = "${format("%s internal JNLP elb", var.name)}"
    Environment = "${var.environment}"
  }
}


// The ELB name.
output "internal_name" {
  value = "${aws_elb.internal.name}"
}

// The ELB ID.
output "internal_id" {
  value = "${aws_elb.internal.id}"
}

// The ELB external dns_name.
output "internal_dns" {
  value = "${aws_elb.internal.dns_name}"
}

// FQDN built using the zone domain and name (internal) for HTTP and JNLP access
output "internal_fqdn" {
  value = "${aws_route53_record.internal.fqdn}"
}

// The zone id of the ELB
output "internal_zone_id" {
  value = "${aws_elb.internal.zone_id}"
}
