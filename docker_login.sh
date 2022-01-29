#!/bin/sh

set -ev

# init key for pass
gpg --batch --gen-key <<-EOF
%echo Generating a standard key
Key-Type: DSA
Key-Length: 1024
Subkey-Type: ELG-E
Subkey-Length: 1024
Name-Real: GHDL [travis-ci]
Name-Email: ghdl@travis-ci
Expire-Date: 0
# Do a commit here, so that we can later print "done" :-)
%commit
%echo done
EOF

key=$(gpg --no-auto-check-trustdb --list-secret-keys | grep ^sec | cut -d/ -f2 | cut -d" " -f1)
PATH="$PATH:$(pwd)"
export PATH
pass init "$key"

curl -fsSL https://github.com/docker/docker-credential-helpers/releases/download/v0.6.4/docker-credential-pass-v0.6.4-amd64.tar.gz | tar xzv

if [ -f "/usr/bin/docker-credential-pass" ]; then
    sudo rm -f /usr/bin/docker-credential-pass
fi
sudo mv docker-credential-pass /usr/bin/
sudo chmod +x /usr/bin/docker-credential-pass
docker-credential-pass list

mkdir ~/.docker
echo "{ \"credsStore\": \"pass\" }" > ~/.docker/config.json

echo "$DOCKERHUB_REGISTRY_PASSWORD" | docker login -u "$DOCKERHUB_REGISTRY_USERNAME" --password-stdin