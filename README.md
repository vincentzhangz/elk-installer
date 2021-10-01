# ELK Installer

Elasticsearch Logstash Kibana stack 7.15.0 installer

## Prerequisites

- System must be Fedora, RHEL, CentOS, or Rocky Linux
- User must have root access on the system
- IP Static (recommended)

## How To Use

1. Clone this repo and then navigate to elk-installer in the system where you want to run the ELK stack

```
git clone https://github.com/vincentzhangz/elk-installer && cd elk-installer
```

2. Make install.sh as executable

```
sudo chmod +x ./install.sh
```

3. Run install.sh

```
sudo ./install.sh
```

4. Access Kibana

```
http://server_ip:5601
```

## Additional Reference Materials

Fore more detailed information on ELK, visit the Elastic configuration guides below:

[Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/settings.html)

[Logstash](https://www.elastic.co/guide/en/logstash/current/configuration.html)

[Kibana](https://www.elastic.co/guide/en/kibana/current/settings.html)
