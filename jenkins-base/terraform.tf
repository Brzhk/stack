variable "image_namespace" {
  description = "A namespace for your custom jenkins image"
}

data "aws_caller_identity" "account" {
}

resource "aws_efs_file_system" "jenkins" {

  tags {
    Name = "jenkins"
  }
}

resource "aws_ecr_repository" "jenkins" {
  name = "${format("%s/jenkins", var.image_namespace)}"

  provisioner "local-exec" {
    command = "${format("cd %s/docker && ./deploy-image.sh %s %s", path.module, self.repository_url, self.name)}"
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
