#!/bin/bash

if [ ! "`whoami`" = "root" ]; then
    echo "\nPlease run script as root."
    exit 1
fi

if [ -f /root/.env ]; then
  export $(cat /root/.env | grep -v '#' | awk '/=/ {print $1}')
fi

UBUNTU_SWAP=${UBUNTU_SWAP:-1G}

echo "[bootstrap] ubuntu version"
lsb_release -a

echo "[bootstrap] house keeping"
apt-get -y -qq update && apt-get -y -qq upgrade && apt-get -y -qq autoremove
apt-get install -y -qq debconf-utils
timedatectl set-timezone Asia/Seoul && date

echo "[boostrap] adding swap file"
fallocate -l ${UBUNTU_SWAP} /swapfile && chmod 600 /swapfile
mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap defaults 0 0' | tee -a /etc/fstab

UBUNTU_PERMIT_PASS=${UBUNTU_PERMIT_PASS:-false}
if [ "$UBUNTU_PERMIT_PASS" = true ]; then
    echo "[bootstrap] permit password login"
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
    service sshd restart
fi

UBUNTU_USER=${UBUNTU_USER:-ubuntu}
UBUNTU_USER_PASS=${UBUNTU_USER_PASS:-ubuntu}
UBUNTU_USER_SUDO=${UBUNTU_USER_SUDO:-false}

if ! id "$UBUNTU_USER" &>/dev/null; then
    echo [bootstrap] add user $UBUNTU_USER
    adduser --gecos "" --disabled-password $UBUNTU_USER
    chpasswd <<< "$UBUNTU_USER:$UBUNTU_USER_PASS"
    echo [bootstrap] added $UBUNTU_USER user
    if [ "$UBUNTU_USER_SUDO" = true ] ; then
        if ! groups "$UBUNTU_USER" | grep -q '\bsudo\b' ; then
            usermod -aG sudo $UBUNTU_USER
            echo "$UBUNTU_USER ALL=(ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/${UBUNTU_USER}
            echo [bootstrap] added $UBUNTU_USER to sudoers
        else
            echo [bootstrap] $UBUNTU_USER is already sudoer.
        fi
    fi
else
    echo [bootstrap] $UBUNTU_USER exists.
fi
