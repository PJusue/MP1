#!/bin/bash
apt-get upgrade -y
apt-get update -y
apt-get install apache2 -y
apt-get install git -y
echo "Todo instalado"
sleep 20
git clone git@github.com:illinoistech-itm/pjusue.git /home/ubuntu/pjusue
chown ubuntu:ubuntu /home/ubuntu/*
cd /home/ubuntu/
cp pjusue/ITMO-544/MP1/index.html /var/www/html
while [ ! -e /dev/xvdf ]
do
sleep 2
done
mkfs.ext4 /dev/xvdf
mkdir /mnt/datadisk
mount /dev/xvdf /mnt/datadisk/
