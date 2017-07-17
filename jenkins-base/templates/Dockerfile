FROM jenkins:latest

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y sudo
RUN echo "jenkins ALL=NOPASSWD: ALL" >> /etc/sudoers
RUN rm /usr/share/jenkins/ref/init.groovy.d/tcp-slave-agent-port.groovy


RUN apt-get update
RUN apt-get install git jq python-pip python-yaml -y
RUN rm -rf /var/lib/apt/lists/*

USER jenkins

RUN sudo -H pip install --upgrade awscli
RUN sudo -H pip install --upgrade boto3
RUN sudo -H pip install --upgrade virtualenv

COPY ref /usr/share/jenkins/


RUN /usr/local/bin/install-plugins.sh git amazon-ecs amazon-ecr github-oauth github-branch-source blueocean

