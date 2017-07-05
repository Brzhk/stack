#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive
echo $(dpkg -l "*$(uname -r)*" | grep image | awk '{print $2}') hold
systemctl disable apt-daily.service
systemctl disable apt-daily.timer

apt-get update -y
apt-get upgrade -y

apt-get install -y \
        build-essential  \
        git \
        wget \
        dkms \
        apt-transport-https \
        ca-certificates \
        python-apt \
        python-pip \
        curl \
        netcat \
        ngrep \
        dstat \
        nmon \
        iptraf \
        iftop \
        iotop \
        atop \
        mtr \
        tree \
        unzip \
        sysdig \
        git \
        htop \
        jq \
        ntp \
        logrotate \
        dhcping \
        nfs-common \
        curl \
        unzip \
        jq \
        dhcpdump

pip install awscli

echo "AWS_REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:')" >> /etc/environment