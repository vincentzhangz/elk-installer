#!/bin/bash

ELK_VERSION=7.15.0
IP_ADDRESS=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
JVM_OPTION_SIZE=1g
APP_LIST=("elasticsearch" "kibana" "logstash")

if [ "$EUID" -ne 0 ]; then
   echo "Please run as root"
   exit
fi

configure() {
   echo "Configuring $1..."
   TEMPLATE_DIR=./config/$1
   INSTALL_DIR=/etc/$1
   cp $TEMPLATE_DIR/$1-template.yml $TEMPLATE_DIR/$1.yml
   sed -i "s/IP_ADDRESS/$IP_ADDRESS/" $TEMPLATE_DIR/$1.yml

   case $1 in
   "elasticsearch")
      cp $TEMPLATE_DIR/jvm-template.options $TEMPLATE_DIR/jvm.options
      sed -i "s/JVM_OPTION_SIZE/$JVM_OPTION_SIZE/" $TEMPLATE_DIR/jvm.options
      cp $INSTALL_DIR/jvm.options $INSTALL_DIR/jvm.options.bak
      mv $TEMPLATE_DIR/jvm.options $INSTALL_DIR/jvm.options
      ;;
   "kibana")
      firewall-cmd --add-port=5601/tcp --permanent
      firewall-cmd --reload
      ;;
   "logstash") ;;

   *) echo "invalid option" ;;
   esac

   cp $INSTALL_DIR/$1.yml $INSTALL_DIR/$1.yml.bak
   systemctl daemon-reload
   systemctl enable --now $1
}

echo "---------------------------------------------------------------"
echo "$(date)"
echo "Starting ELK Installer "
echo "ELK Stack $ELK_VERSION "
echo "Elasticsearch - Logstash - Kibana "
echo "IP Address : $IP_ADDRESS"
echo "---------------------------------------------------------------"
echo ""

echo "System Update... "
dnf upgrade --refresh -y >/dev/null

echo "Adding Elasticsearch repo..."
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
cat >/etc/yum.repos.d/elasticstack.repo <<EOL
[elasticsearch]
name=Elasticsearch repository for 7.x packages
baseurl=https://artifacts.elastic.co/packages/7.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOL

dnf upgrade --refresh -y >/dev/null

for i in "${APP_LIST[@]}"; do
   :
   echo "Installing $i..."
   dnf install $i -y >/dev/null
   configure $i
done

for i in "${APP_LIST[@]}"; do
   :
   echo "Setting up config for $i..."
   mv ./config/$i/$i.yml /etc/$i/$i.yml
   systemctl restart $i
done

echo "Access kibana at http://$IP_ADDRESS:5601/"
