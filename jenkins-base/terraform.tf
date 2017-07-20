variable "image_namespace" {
  description = "A namespace for your custom jenkins image"
}

variable "admin_username" {
  description = "A (casesensitive?) username for the administrator account to be created on jenkins"
  default     = "admin"
}

variable "admin_email_address" {
  default = ""
}

variable "public_domain_name" {
}

variable "domain_name" {
  default = "stack.local"
}

variable "cluster_name" {
  default = "forge"
}

variable "container_jnlp_port" {
  description = "The container port for JNLP Slave connection"
  default     = 50000
}

data "aws_caller_identity" "account" {
}

resource "aws_efs_file_system" "jenkins" {

  tags {
    Name = "jenkins"
  }
}

resource "aws_ecr_repository" "jenkins" {
  name       = "${format("%s/jenkins", var.image_namespace)}"

  provisioner "local-exec" {
    command = <<EOC
cat <<EOF >${path.module}/docker/init.groovy.d/minConfig.groovy
${data.template_file.container_cfg_script.rendered}
EOF
EOC
  }

  provisioner "local-exec" {
    command = "${format("cd %s/docker && ./deploy-image.sh %s %s", path.module, self.repository_url, self.name)}"
  }

  depends_on = ["data.template_file.container_cfg_script"]
}

data "template_file" "container_cfg_script" {
  template = "${file("${path.module}/templates/minConfig.groovy")}"

  vars {
    ADMIN_USERNAME      = "${var.admin_username}"
    ADMIN_EMAIL_ADDRESS = "${coalesce(var.admin_email_address, format("no-reply@%s", var.public_domain_name))}"
    CONTAINER_JNLP_PORT = "${var.container_jnlp_port}"
    EXTERNAL_FQDN       = "jenkins.${var.public_domain_name}"
    INTERNAL_FQDN       = "jenkins.${var.domain_name}"
    AWS_ACCOUNT_ID      = "${data.aws_caller_identity.account.account_id}"
    AWS_REGION          = "eu-west-1"
    CLUSTER_NAME        = "${var.cluster_name}"
  }
}

output "ecr_repository_url" {
  value = "${aws_ecr_repository.jenkins.repository_url}"
}

output "ecr_registry_id" {
  value = "${aws_ecr_repository.jenkins.registry_id}"
}

output "efs_id" {
  value = "${aws_efs_file_system.jenkins.id}"
}

output "container_jnlp_port" {
  value = "${var.container_jnlp_port}"
}

output "aws_account_id" {
  value = "${data.aws_caller_identity.account.account_id}"
}

output "cluster_name" {
  value = "${var.cluster_name}"
}
