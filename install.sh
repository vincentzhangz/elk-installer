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

if [[ $1 == "--xpack" ]]
   then
   echo "Configuring xpack..."
   echo "
xpack.security.enabled: true
xpack.security.authc.api_key.enabled: true" >> ./config/elasticsearch/elasticsearch.yml

   cp ./config/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml
   systemctl restart elasticsearch

   RAW_PASSWORD_LIST=$(echo y | /usr/share/elasticsearch/bin/elasticsearch-setup-passwords auto)

   if [ -z "$RAW_PASSWORD_LIST" ]
      then
      echo "Password list already generated"
   else
      echo "$RAW_PASSWORD_LIST" >> ./password
      echo "Password list generated"
   fi
   # PASSWORD LIST ORDER
   # 0 apm_system
   # 1 kibana_system
   # 2 kibana
   # 3 logstash_system
   # 4 beats_system
   # 5 remote_monitoring_user
   # 6 elastic

   PASSWORD_LIST=()
   IFS=', ' read -r -a temp <<< "$RAW_PASSWORD_LIST"

   PATTERN="[a-zA-Z0-9]{20}$"

   for index in "${!temp[@]}"
   do
   if  [[ ${temp[index]} =~ $PATTERN ]]; then
      echo "${temp[index]}"
      PASSWORD_LIST+=(${temp[index]})
   fi
   done

   echo "
elasticsearch.username: \"kibana_system\"
elasticsearch.password: \"${PASSWORD_LIST[1]}\"" >> ./config/kibana/kibana.yml

   echo "
xpack.monitoring.enabled: true
xpack.monitoring.elasticsearch.username: logstash_system
xpack.monitoring.elasticsearch.password: ${PASSWORD_LIST[3]}
xpack.monitoring.elasticsearch.hosts: [\"http://$IP_ADDRESS:9200\"]
xpack.monitoring.collection.interval: 10s
xpack.monitoring.collection.pipeline.details.enabled: true" >> ./config/logstash/logstash.yml
fi

for i in "${APP_LIST[@]}"; do
   :
   echo "Setting up config for $i..."
   mv ./config/$i/$i.yml /etc/$i/$i.yml
   systemctl restart $i
done

echo "Access kibana at http://$IP_ADDRESS:5601/"
