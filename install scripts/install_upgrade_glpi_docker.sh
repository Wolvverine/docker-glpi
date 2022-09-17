#!/bin/sh
set -a
set -x

containername="glpi"
imagetag="nginx-74-10.0.3-3.5.1"
imagename="wolvverine/docker-glpi"
restartpolicy="unless-stopped"

docker volume create "$containername"-data
docker volume create "$containername"-config
docker network create "$containername"-network

# These two volumes are not required and optional for developers
docker volume create "$containername"-plugins
docker volume create "$containername"-marketplace


sudo docker pull  "$imagename:$imagetag" && sudo docker stop $containername
sudo docker rm $containername

docker run --restart "$restartpolicy" --detach  --name "$containername" \
 --publish 80:80 --publish 443:443 \
 --volume "$containername"-data:/var/www/files:Z \
 --volume "$containername"-config:/var/www/config:Z \
 --volume "$containername"-plugins:/var/www/plugins:Z \
 --volume "$containername"-marketplace:/var/www/marketplace:Z \
 --net "$containername"-network \
 -e PHPFPM_PM_MAX_CHILDREN=40 -e PHPFPM_PM_PROCESS_IDLE_TIMEOUT=120s \
 -e PHPFPM_PM_MAX_REQUEST=2000 -e PHPFPM_PM_MAX_SPARE_SERVERS=10 \
 -e PHPFPM_PM_MIN_SPARE_SERVERS=5 -e PHPFPM_PM_START_SERVERS=10 -e PHP_MEMORY_LIMIT=256M \
 -e GLPI_CHMOD_PATHS_FILES=yes -e GLPI_REMOVE_INSTALLER=yes \
 -e GLPI_ENABLE_CRONJOB=yes  -e TZ="Europe/Warsaw" \
 -e GLPI_INSTALL_PLUGINS="\
behaviors|https://github.com/yllen/behaviors/releases/download/v2.7.1/glpi-behaviors-2.7.1.tar.gz,\
pdf|https://github.com/yllen/pdf/releases/download/v2.1.0/glpi-pdf-2.1.0.tar.gz,\
vip|https://github.com/InfotelGLPI/vip/releases/download/1.8.1/glpi-vip-1.8.1.tar.bz2,\
statecheck|https://github.com/ericferon/glpi-statecheck/releases/download/v2.3.7/statecheck-v2.3.7.tar.gz" \
 "$repositoryname:$imagetag"

docker start $containername
sleep 5s
#Disable IPv6 for Nginx if you not use
docker exec -t $containername sed -i 's/listen \[::\]:80 default_server;/#listen \[::\]:80 default_server;/g' /etc/nginx/conf.d/default.conf
docker exec -t $containername sed -i 's/listen \[::\]:80 default_server;/#listen \[::\]:80 default_server;/g' /etc/nginx/nginx.conf
docker restart $containername

sleep 20s

docker logs $containername -n 50
