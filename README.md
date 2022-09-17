# Docker GLPI

![Build Status - Master](https://github.com/Wolvverine/docker-glpi/actions/workflows/github-actions-build.yml/badge.svg?branch=master)

![Build Status - Development](https://github.com/Wolvverine/docker-glpi/actions/workflows/github-actions-build.yml/badge.svg?branch=develop)

This images contains an instance of GLPI web application served by nginx and php-fpm on port 80.

:warning: Take care of the [changelogs](CHANGELOG.md) because some breaking changes may happen between versions.

## Supported tags, image variants and respective Dockerfile links

* nginx and PHP7.4 embedded [Dockerfile](https://github.com/Wolvverine/docker-glpi/blob/master/Dockerfile_nginx-74)

    * `nginx-74-9.5.9-3.5.1`
    * `nginx-74-10.0.3-3.5.1`

* Development versions with and without Xdebug:

    * `nginx-74-9.5.9-3.5.1-develop`
    * `nginx-74-10.0.3-3.5.1-develop`
    * `nginx-74-xdebug-9.5.9-3.5.1-develop`
    * `nginx-74-xdebug-10.0.3-3.5.1-develop`


## Docker Informations

* This image expose the following ports

| Port           | Usage                |
| -------------- | -------------------- |
| 80/tcp         | HTTP web application |

[see https part to known about ssl](#https---ssl-encryption)

 * This image takes theses environnements variables as parameters

| Environment                    | Type             | Usage                                                                     | Default  |
| ------------------------------ | ---------------- | ------------------------------------------------------------------------- | -------- |
| TZ                             | String           | Contains the timezone                                                     |          |
| GLPI_REMOVE_INSTALLER          | Boolean (yes/no) | Set to yes if it's not the first installation of glpi                     | no       |
| GLPI_CHMOD_PATHS_FILES         | Boolean (yes/no) | Set to yes to apply chmod/chown on /var/www/files (useful for host mount) | no       |
| GLPI_INSTALL_PLUGINS           | String           | Comma separated list of plugins to install (see below)                    |          |
| PHP_MEMORY_LIMIT               | String           | see PHP memory_limit configuration                                        | 64M      |
| PHP_UPLOAD_MAX_FILESIZE        | String           | see PHP upload filesize configuration                                     | 16M      |
| PHP_MAX_EXECUTION_TIME         | String           | see PHP max execution time configuration                                  | 3600     |
| PHP_POST_MAX_SIZE              | String           | see PHP post_max_size configuration                                       | 20M      |
| PHP_OPCACHE_MEM_CONSUMPTION    | String           | see PHP opcache_mem_consumption configuration                             | 256      |
| PHPFPM_PM                      | String           | see PHPFPM pm configuration                                               | dynamic  |
| PHPFPM_PM_MAX_CHILDREN         | Integer          | see PHPFPM pm.max_children configuration                                  | 30       |
| PHPFPM_PM_START_SERVERS        | Integer          | see PHPFPM pm.start_servers configuration                                 | 4        |
| PHPFPM_PM_MIN_SPARE_SERVERS    | Integer          | see PHPFPM pm.min_spare_servers configuration                             | 4        |
| PHPFPM_PM_MAX_SPARE_SERVERS    | Integer          | see PHPFPM pm.max_spare_servers configuration                             | 8        |
| PHPFPM_PM_PROCESS_IDLE_TIMEOUT | Mixed            | see PHPFPM pm.process_idle_timeout configuration                          | 120s     |
| PHPFPM_PM_MAX_REQUEST          | Integer          | see PHPFPM pm.max_request configuration                                   | 2000     |
| ------------------------------ | ---------------- | ------------------------------------------------------------------------- | -------- |
| PHPFPM_XDEBUG_CLIENT_PORT      | Integer          | Contains xdebug client host port                                          |          |
| PHPFPM_XDEBUG_CLIENT_HOST      | String           | Contains xdebug client host IP or DNS name                                |          |
| ______________________________ | ________________ | _________________________________________________________________________ | ________ |

The GLPI_INSTALL_PLUGINS variable must contains the list of plugins to install (download and extract) before starting glpi.
This environment variable is a comma separated list of plugins definitions. Each plugin definition must be like this "PLUGINNAME|URL".
The PLUGINNAME is the name of the first folder in plugin archive and will be the glpi's name of the plugin.
The URL is the full URL from which to download the plugin. This url can contains some compressed file extensions, in some case the installer script will not be able to extract it, so you can create an issue with specifying the unhandled file extension.
These two items are separated by a pipe symbol.

To summarize, the GLPI_INSTALL_PLUGINS variable must follow the following skeleton GLPI_INSTALL_PLUGINS="name1|url1,name2|url2"
For better example see at the end of this file.

   * The following volumes are exposed by this image

| Volume             | Usage                                            |
| ------------------ | ------------------------------------------------ |
| /var/www/files     | The data path of GLPI                            |
| /var/www/config    | The configuration path of GLPI                   |


## Application Informations


### HTTPS - SSL encryption

There are many different possibilities to introduce encryption depending on your setup.

As most of available docker image on the internet, I recommend using a reverse proxy in front of this image.
This prevent me to introduce all ssl configurations parameters and also to prevent a limitation of the available parameters.

For example, you can use the popular nginx-proxy and docker-letsencrypt-nginx-proxy-companion containers or Traefik to handle this.


### GLPI Cronjob

GLPI require a job to be run periodically. Starting from 3.0.0 release, this image does not provide any solution to handle this. I've choose to remove cron task from this image to respect docker convention and to prevent a clustered deploiement to run the cron on all cluster instances.

As compensation I provide a wrapper script that wrap the batch execution and return a json object with job execution details at ```/opt/scripts/cronwrapper.py```

To ensure correct GLPI running please put this job in your common cron scheduler.
On linux you can use the /etc/crontab file with a content similar to this one :

```
*/15 * * * * root docker ps | grep --quiet 'glpi' && docker exec --user www-data glpi /opt/scripts/cronwrapper.py --forward-stderr
```


### Timezone issues

Timezone is handled at PHP level in the image since 2.4.2 version, but you might encounter issues if you use different timezone in your database engine.
Please refer to the GLPI documentations to handle this at database level https://glpi-install.readthedocs.io/en/develop/timezones.html.


## Todo

* Normalize log output
* Propose splitted nginx/fpm images
* Add prometheus exporter (https://github.com/vozlt/nginx-module-vts, https://github.com/bakins/php-fpm-exporter)

## Installation

```
docker pull wolvverine/docker-glpi:nginx-72-latest
```


## Usage

The first time you run this image, set the GLPI_REMOVE_INSTALLER variable to 'no', then after this first installation set it to 'yes' to remove the installer.

### Without database link (you can use an ip address or a domain name in the installer gui)

```
docker run --name glpi --publish 8000:80 --volume data-glpi:/var/www/files --volume data-glpi-config:/var/www/config wolvverine/docker-glpi:nginx-56-latest
```

### With database link (if you have any MySQL/MariaDB as a docker container)

#### Create dedicated network

```
docker network create glpi-network
```

#### Start a MySQL instance

```
docker run --name mysql -d --net glpi-network -e MYSQL_DATABASE=glpi -e MYSQL_USER=glpi -e MYSQL_PASSWORD=glpi -e MYSQL_ROOT_PASSWORD=root_password mysql
```

#### Start a GLPI instance

```
docker run --name glpi --publish 8000:80 --volume data-glpi:/var/www/files --volume data-glpi-config:/var/www/config --net glpi-network wolvverine/docker-glpi:nginx-56-latest
```

#### Cron task on Docker host

```
*/5 * * * * root docker ps | grep --quiet 'glpi' && docker exec --user www-data glpi python3 /usr/local/bin/cronwrapper.py  --forward-stderr
* */3 * * * root docker ps | grep --quiet 'glpi' && docker exec --user www-data glpi /var/www/bin/console -n glpi:ldap:synchronize_users --only-update-existing
```

### Docker-compose Specific configuration examples

* Production configuration with already installed GLPI with FusionInventory and dashboard plugin :

```
version: '2.1'
services:

  glpi:
    image: wolvverine/docker-glpi:nginx-74-latest
    environment:
      GLPI_REMOVE_INSTALLER: 'no'
      GLPI_INSTALL_PLUGINS: "
        fusioninventory|https://github.com/fusioninventory/fusioninventory-for-glpi/releases/download/glpi9.4%2B2.4/fusioninventory-9.4+2.4.tar.bz2,\
        dumpentity|https://forge.glpi-project.org/attachments/download/2089/glpi-dumpentity-1.4.0.tar.gz\
        "
    ports:
      - 127.0.0.1:8008:80
    volumes:
      - glpi-data:/var/www/files
      - glpi-config:/var/www/config
    depends_on:
      mysqldb:
        condition: service_healthy
    restart: always
    networks:
      glpi-network:
        aliases:
          - glpi

  mysqldb:
    image: mysql
    healthcheck:
      test: ["CMD", "mysqladmin" ,"ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: always
    command: --default-authentication-plugin=mysql_native_password --character-set-server=utf8
    environment:
      MYSQL_ROOT_PASSWORD: root
    volumes:
      - mysql-glpi-db:/var/lib/mysql
    restart: always
    networks:
      glpi-network:
        aliases:
          - mysqldb

networks:
  glpi-network:
    driver: bridge

volumes:
  glpi-data:
  glpi-config:
  mysql-glpi-db:
```
