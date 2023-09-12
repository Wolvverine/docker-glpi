@ECHO OFF
REM GLPI Install Environment
REM names containers
SET GLPI_container=GLPI
SET DB_Container=MariaDB
REM GLPI Docker repository and dockerhub tags
SET docker_repository=wolvverine/docker-glpi
SET docker_tag=nginx-74-10.0.6-3.6

REM aktualne tagi dla kontenera GLPI
REM www_server-php_version-glpi_version-container_version
REM nginx-82-10.0.6-3.6
REM nginx-74-10.0.6-3.6
REM nginx-82-xdebug-10.0.6-3.6
REM nginx-74-xdebug-10.0.6-3.6
REM https://hub.docker.com/r/wolvverine/docker-glpi/tags

REM Database Docker repository and dockerhub tags
SET docker_DB_repository=mariadb
SET docker_DB_tag=latest

REM Password and user for DB
SET password=your_db_password

REM External ports for containers
SET GLPI_port=6080
SET DB_port=6303


REM ####################################################################

ECHO Volumes for container %GLPI_container%
docker volume create %GLPI_container%-config
docker volume create %GLPI_container%-plugins  
docker volume create %GLPI_container%-marketplace

ECHO  Dedicated internal network for containers: %GLPI_container% and %DB_Container%
docker network create %GLPI_container%-network

ECHO Remove old container %GLPI_container% and pull new image
docker stop %GLPI_container% 
docker rm %GLPI_container% && ^
docker pull  %docker_repository%:%docker_tag%

ECHO Running %GLPI_container% container
docker run --restart unless-stopped --name %GLPI_container% ^
           --publish %GLPI_port%:80 ^
           --volume %GLPI_container%-files:/var/www/files ^
           --volume "%GLPI_container%"-config:/var/www/config ^
           --volume "%GLPI_container%"-plugins:/var/www/plugins ^
           --volume "%GLPI_container%"-marketplace:/var/www/marketplace ^
           --net "%GLPI_container%"-network ^
           -e GLPI_CHMOD_PATHS_FILES=yes ^
           -e GLPI_REMOVE_INSTALLER=no ^
           -e GLPI_ENABLE_CRONJOB=yes ^
           -e PHP_MEMORY_LIMIT=128M ^
           -e TZ="Europe/Warsaw" ^
            -e GLPI_INSTALL_PLUGINS="fusioninventory|https://github.com/fusioninventory/fusioninventory-for-glpi/releases/download/glpi10.0.6+1.1/fusioninventory-10.0.6+1.1.tar.bz2,fields|https://github.com/pluginsGLPI/fields/releases/download/1.20.6/glpi-fields-1.20.6.tar.bz2,datainjection|https://github.com/pluginsGLPI/datainjection/releases/download/2.13.2/glpi-datainjection-2.13.2.tar.bz2,genericobject|https://github.com/pluginsGLPI/genericobject/releases/download/2.14.3/glpi-genericobject-2.14.3.tar.bz2" ^
           -d %docker_repository%:%docker_tag%

REM ####################################################################
ECHO  MARIADB

ECHO Volume for %DB_Container% container
docker volume create %DB_Container%-%GLPI_container%-data

ECHO Remove old %DB_Container% container and pull new image
docker stop %DB_Container%
docker rm %DB_Container% && ^
docker pull  %docker_DB_repository%:%docker_DB_tag%

ECHO Running %DB_Container% container
docker run --restart always --name %DB_Container% --net %GLPI_container%-network ^
           -p %DB_port%:3306 ^
           --volume %DB_Container%-%GLPI_container%-data:/var/lib/mysql ^
           -e MYSQL_ROOT_PASSWORD=%password% ^
           -d %docker_DB_repository%:%docker_DB_tag%

ECHO Commands in %DB_Container% container - wait
REM TODO wait for full start container server
timeout 60 > NUL
ECHO Check databases
docker exec -it %DB_Container% mariadb-check  --all-databases --check-upgrade --auto-repair -u root --password=%password%
ECHO Upgrade databases
docker exec -it %DB_Container% mariadb-upgrade -u root --password=%password%
ECHO Timezone
docker exec -it %DB_Container% sh -c "export TZ='Europe/Warsaw'"
docker exec -it %DB_Container% sh -c "rm /etc/localtime"
docker exec -it %DB_Container% sh -c "ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone"
timeout 5 > NUL
start "" http://localhost:%GLPI_port%
start "" \\wsl$\docker-desktop-data\data\docker\volumes
PAUSE