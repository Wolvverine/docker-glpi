#!/bin/sh
set -a
set -x

containername="phpmyadmin"
imagename="phpmyadmin"
imagetag="latest"
restartpolicy="unless-stopped"
dbcontainername="mariadb"
glpicontainername="glpi"

#first time
docker volume create "$containername"-data

sudo docker pull  $imagename:$imagetag && \
sudo docker stop $containername
sudo docker rm $containername

docker run --detach --restart $restartpolicy --name "$containername" \
 -p 8080:80  \
 --net "$glpicontainername"-network \
 -e PMA_ARBITRARY='1' -e PMA_HOST="$dbcontainername" -e PMA_VERBOSE='1' -e PMA_PORT='3306' \
 --volume  "$containername"-data:/etc/phpmyadmin/:Z  \
 $imagename:$imagetag

docker exec -it $containername /bin/sh -c "export TZ='Europe/Warsaw'"
docker exec -it $containername /bin/sh -c "rm /etc/localtime"
docker exec -it $containername /bin/sh -c "ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone"
