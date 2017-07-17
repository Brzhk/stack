/**
 * The web-service is similar to the `service` module, but the
 * it provides a __public__ ELB instead.
 *
 * Usage:
 *
 *      module "auth_service" {
 *        source    = "github.com/segmentio/stack/service"
 *        name      = "auth-service"
 *        image     = "auth-service"
 *        cluster   = "default"
 *      }
 *
 */

variable "environment" {
  description = "Environment tag, e.g prod"
}

variable "subnet_ids" {
  description = "Comma separated list of subnet IDs that will be passed to the ELB module"
}

variable "vpc_id" {
  description = "The VPC ID"
}

variable "internal_elb_security_group_id" {
  description = "the internal-elb-sg ID"
}

variable "external_elb_security_group_id" {
  description = "the internal-elb-sg ID"
}

variable "cluster" {
  description = "The cluster name or ARN"
}

variable "cluster_asg" {
  description = "The cluster ASG id"
}

variable "log_bucket" {
  description = "The S3 bucket ID to use for the ELB"
}

variable "backup_bucket" {
  description = "The S3 bucket ID to use for the EFS backup"
}

variable "ssl_certificate_id" {
  description = "SSL Certificate ID to use"
}

variable "iam_role" {
  description = "IAM Role ARN to use"
}

variable "image" {
  description = "The docker image name, e.g jenkins"
  default     = "jenkins"
}

variable "name" {
  description = "The service name, if empty the service name is defaulted to the image name"
  default     = "jenkins"
}

variable "version" {
  description = "The docker image version"
  default     = "latest"
}

variable "external_dns_name" {
  description = "The subdomain under which the ELB is exposed externally, defaults to the task name"
  default     = "jenkins"
}

variable "internal_dns_name" {
  description = "The subdomain under which the ELB is exposed internally, defaults to the task name"
  default     = "jenkins"
}

variable "external_zone_id" {
  description = "The zone ID to create the record in"
}

variable "internal_zone_id" {
  description = "The zone ID to create the record in"
}

variable "cidr" {
  description = "The cidr block to use for internal security groups"
}

variable "container_http_port" {
  description = "The container port"
  default     = 8080
}

variable "instance_http_port" {
  description = "The container host port"
}

variable "elb_jnlp_port" {
  description = "ELB port for JNLP Slave connection"
  default     = 50000
}

variable "container_jnlp_port" {
  description = "The container port"
  default     = 50000
}

variable "instance_jnlp_port" {
  description = "Instance port for JNLP Slave connection"
  default     = 50000
}

variable "command" {
  description = "The raw json of the task command"
  default     = "[]"
}

variable "env_vars" {

  description = "The raw json of the task env vars"
  default     = <<EOF
  [
      {
        "name": "JAVA_OPTS",
        "value": "-Djenkins.install.runSetupWizard=false"
      }
  ]
EOF
}

variable "desired_count" {

  description = "The desired count"
  default     = 1
}

variable "memory" {

  description = "The number of MiB of memory to reserve for the container"
  default     = 2048
}

variable "cpu" {

  description = "The number of cpu units to reserve for the container"
  default     = 512
}

variable "deployment_minimum_healthy_percent" {

  description = "lower limit (% of desired_count) of # of running tasks during a deployment"
  default     = 100
}

variable "deployment_maximum_percent" {

  description = "upper limit (% of desired_count) of # of running tasks during a deployment"
  default     = 200
}


resource "aws_ecs_service" "main" {

  name                               = "${aws_ecs_task_definition.main.family}"
  cluster                            = "${var.cluster}"
  task_definition                    = "${aws_ecs_task_definition.main.arn}"
  desired_count                      = "${var.desired_count}"
  iam_role                           = "${var.iam_role}"
  deployment_minimum_healthy_percent = "${var.deployment_minimum_healthy_percent}"
  deployment_maximum_percent         = "${var.deployment_maximum_percent}"

  load_balancer {
    elb_name       = "${module.elb.internal_id}"
    container_name = "${aws_ecs_task_definition.main.family}"
    container_port = "${var.container_http_port}"
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_ecs_task_definition" "main" {
  family                = "jenkins"

  lifecycle {
    ignore_changes        = ["image"]
    create_before_destroy = true
  }

  container_definitions = <<EOF
[
  {
    "image": "${var.image}",
    "name": "${coalesce(var.name, replace(var.image, "/", "-"))}",

    "essential": true,

    "memory": ${var.memory},
    "cpu": ${var.cpu},

    "portMappings": [
      {
        "containerPort": ${var.container_http_port},
        "hostPort": ${var.instance_http_port}
      },
      {
        "containerPort": ${var.container_jnlp_port},
        "hostPort": ${var.instance_jnlp_port}
      }
    ],

    "mountPoints": [
      {
        "sourceVolume": "efs-jenkins",
        "containerPath": "/var/jenkins_home"
      }
    ],

    "environment": [
      {
        "name": "JAVA_OPTS",
        "value": "-Djenkins.install.runSetupWizard=false"
      }
    ],

    "logConfiguration": {
      "logDriver": "journald",
      "options": {
        "tag": "${coalesce(var.name, replace(var.image, "/", "-"))}"
      }
    }
  }
]
EOF

  volume {

    name      = "efs-jenkins"
    host_path = "/mnt/efs-jenkins"
  }
}

module "elb" {
  source                         = "./elb"

  name                           = "${aws_ecs_task_definition.main.family}"
  http_port                      = "${var.instance_http_port}"
  environment                    = "${var.environment}"
  subnet_ids                     = "${var.subnet_ids}"
  external_dns_name              = "${coalesce(var.external_dns_name, aws_ecs_task_definition.main.family)}"
  internal_dns_name              = "${coalesce(var.internal_dns_name, aws_ecs_task_definition.main.family)}"
  external_zone_id               = "${var.external_zone_id}"
  internal_zone_id               = "${var.internal_zone_id}"
  log_bucket                     = "${var.log_bucket}"
  ssl_certificate_id             = "${var.ssl_certificate_id}"
  cidr                           = "${var.cidr}"
  internal_elb_security_group_id = "${var.internal_elb_security_group_id}"
  external_elb_security_group_id = "${var.external_elb_security_group_id}"
  jnlp_port                      = "${var.instance_jnlp_port}"
  vpc_id                         = "${var.vpc_id}"
  elb_jnlp_port                  = "${var.elb_jnlp_port}"
}

resource "aws_iam_role_policy" "backup_s3_access_instance_role_policy" {
  name   = "jenkins-s3bckp-access-policy-${var.name}-${var.environment}"
  role   = "${var.iam_role}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:ListAllMyBuckets",
      "Resource": "arn:aws:s3:::*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::${var.backup_bucket}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::${var.backup_bucket}/*"
    }
  ]
}
EOF
}

resource "aws_autoscaling_attachment" "extattach" {
  autoscaling_group_name = "${var.cluster_asg}"
  elb                    = "${module.elb.external_id}"
}
// The name of the ELB
output "name" {
  value = "${module.elb.internal_name}"
}

// The DNS name of the ELB
output "dns" {
  value = "${module.elb.internal_dns}"
}

// The id of the ELB
output "elb" {
  value = "${module.elb.internal_id}"
}

// The zone id of the ELB
output "zone_id" {
  value = "${module.elb.internal_zone_id}"
}

// FQDN built using the zone domain and name (external)
output "external_fqdn" {
  value = "${module.elb.external_fqdn}"
}

// FQDN built using the zone domain and name (internal)
output "internal_fqdn" {
  value = "${module.elb.internal_fqdn}"
}
