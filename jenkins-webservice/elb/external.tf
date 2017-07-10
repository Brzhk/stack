



variable "external_elb_security_group_id" {
  description = "the external-elb-sg ID"
}

variable "external_dns_name" {
  description = "The subdomain under which the ELB is exposed externally, defaults to the task name"
}

variable "external_zone_id" {
  description = "The zone ID to create the record in"
}

variable "ssl_certificate_id" {
  description = "The ARN of the certificate  ID to create the record in (Optional)"
}

/**
 * Resources.
 */
resource "aws_elb" "external" {
  name                        = "${var.name}"

  internal                    = false
  cross_zone_load_balancing   = true
  subnets                     = ["${split(",", var.subnet_ids)}"]
  security_groups             = ["${var.external_elb_security_group_id}"]
  idle_timeout                = 30
  connection_draining         = true  // TODO check if connection draining is pertinent
  connection_draining_timeout = 15

  listener {
    // provided for external access
    lb_port            = 443
    lb_protocol        = "https"
    instance_port      = "${var.http_port}"
    instance_protocol  = "http"
    ssl_certificate_id = "${var.ssl_certificate_id}"
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
    Name        = "${var.name}-balancer"
    Service     = "${var.name}"
    Environment = "${var.environment}"
  }
}

resource "aws_route53_record" "external" {
  zone_id = "${var.external_zone_id}"
  name    = "${var.external_dns_name}"
  type    = "A"

  alias {
    zone_id                = "${aws_elb.external.zone_id}"
    name                   = "${aws_elb.external.dns_name}"
    evaluate_target_health = false
  }
}

resource "aws_security_group" "external_https_elb" {
  name        = "${format("%s-%s-external-https-elb", var.name, var.environment)}"
  vpc_id      = "${var.vpc_id}"
  description = "Allows external HTTPS ELB traffic to jenkins"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
    Name        = "${format("%s external HTTPS elb", var.name)}"
    Environment = "${var.environment}"
  }
}

// The ELB name.
output "external_name" {
  value = "${aws_elb.external.name}"
}

// The ELB ID.
output "external_id" {
  value = "${aws_elb.external.id}"
}

// The ELB external dns_name.
output "external_dns" {
  value = "${aws_elb.external.dns_name}"
}

// FQDN built using the zone domain and name (external) for HTTP and JNLP access
output "external_fqdn" {
  value = "${aws_route53_record.external.fqdn}"
}

// The zone id of the ELB
output "external_zone_id" {
  value = "${aws_elb.external.zone_id}"
}
