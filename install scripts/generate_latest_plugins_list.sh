#!/bin/bash
# Purpose: Generate latest plugis list for instalation script
# Author: Michał Panasiewicz under GPL v3.0+
# ------------------------------------------
INPUT=plugins_repo_list.csv
OLDIFS=$IFS
IFS=','
[ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }

while read -r folder organization repository
do
browser_download_url="$(curl https://api.github.com/repos/"$organization"/"$repository"/releases/latest -s | jq -r '.assets[0].browser_download_url')"
echo "$folder|$browser_download_url,\\"
done < $INPUT
IFS=$OLDIFS

#
