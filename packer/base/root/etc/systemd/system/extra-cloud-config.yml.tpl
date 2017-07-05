#cloud-config
bootcmd:
  - echo "AVAILABILITY_ZONE=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)" >> /etc/environment
  - echo 'EFS_ID=${efs_id}' >> /etc/environment
  - mkdir -p /mnt/efs-jenkins
  - apt-get install -qq nfs-common curl unzip
  - mount -a
  - chown -R 1000:1000 /mnt/efs-jenkins
  - gpasswd -a ubuntu§ docker
  - systemctl daemon-reload
  - systemctl restart docker.service

