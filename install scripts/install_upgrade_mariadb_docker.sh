#!/bin/sh
set -a
set -x

containername="mariadb"
imagename="mariadb"
imagetag="latest"
restartpolicy="unless-stopped"
glpicontainername="glpi"
dbpassword="your_db_root_password"

#first time
docker volume create "$containername"-"$glpicontainername"-data
docker volume create "$containername"-"$glpicontainername"-config
docker network create "$glpicontainername"-network

sudo docker stop $glpicontainername
sudo docker pull  $imagename:$imagetag && \
sudo docker stop $containername
sudo docker rm $containername

docker run --detach --restart $restartpolicy --name "$containername" \
 --net "$glpicontainername"-network \
 -p 3306:3306 \
 --volume  "$containername"-"$glpicontainername"-data:/var/lib/mysql:Z \
 --volume  "$containername"-"$glpicontainername"-config:/etc/mysql:Z \
 -e MYSQL_ROOT_PASSWORD="$dbpassword" \
 $imagename:$imagetag

echo "Wait for start container $containername ."
sleep 60
docker exec -it $containername mariadb-check --all-databases --check-upgrade --auto-repair -u root --password="$dbpassword"
docker exec -it $containername mariadb-upgrade -u root --password="$dbpassword"
docker exec -it $containername /bin/sh -c "export TZ='Europe/Warsaw'"
docker exec -it $containername /bin/sh -c "rm /etc/localtime"
docker exec -it $containername /bin/sh -c "ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone"