#!/bin/sh
set -e

#generate entropy for gpg
sudo rngd -r /dev/urandom

# init key for pass
GPG_TTY="$(tty)" 
export GPG_TTY  
gpg --batch --gen-key <<-EOF
%echo Generating a standard key
Key-Type: DSA
Key-Length: 1024
Subkey-Type: ELG-E
Subkey-Length: 1024
Name-Real: GHDL [travis-ci]
Name-Email: ghdl@travis-ci
Expire-Date: 1
%no-ask-passphrase
%no-protection
# Do a commit here, so that we can later print "done" :-)
%commit
%echo done
EOF

key=$(gpg --no-auto-check-trustdb --list-secret-keys --with-colon | grep ^sec | cut -d: -f5 )
# trust this key
printf "5\ny\n" | gpg --command-fd 0 --expert --edit-key "$key" trust
pass init "$key"

# Check for later releases at https://github.com/docker/docker-credential-helpers/releases
version="v0.6.4"
archive="docker-credential-pass-$version-amd64.tar.gz"
url="https://github.com/docker/docker-credential-helpers/releases/download/$version/$archive"

if [ -f "/usr/bin/docker-credential-pass" ]; then
    sudo rm -f /usr/bin/docker-credential-pass
fi
# Download cred helper, unpack, make executable, and move it where Docker will find it.
curl -fsSL $url | tar -xzv \
    && sudo chmod 755 docker-credential-pass \
    && sudo mv -f docker-credential-pass /usr/bin/

### config.json
config_path=~/.docker
config_filename=$config_path/config.json

# Could assume config.json isn't there or overwrite regardless and not use jq (or sed etc.)
# echo '{ "credsStore": "pass" }' > $config_filename

if [ ! -f $config_filename ]
then
    if [ ! -d $config_path ]
    then
        mkdir -p $config_path
    fi

    # Create default docker config file if it doesn't exist (never logged in etc.). Empty is fine currently.
    cat > $config_filename <<EOL
{
}
EOL
    echo "$config_filename created with defaults"
else
    echo "$config_filename already exists"
fi

# Whether config is new or existing, read into variable for easier file redirection (cat > truncate timing)
config_json=$(cat $config_filename)

if [ -z "$config_json" ]; then
    # Empty file will prevent jq from working
    config_json="{}"
fi

# Update Docker config to set the credential store.
echo "$config_json" | jq --arg credsStore pass '. + {credsStore: $credsStore}' > $config_filename

# Output / verify contents
echo "$config_filename:"
jq < $config_filename

echo "$DOCKERHUB_REGISTRY_PASSWORD" | docker login --username "$DOCKERHUB_REGISTRY_USERNAME" --password-stdin

# This is a required step to unlock your password container since docker push doesn't call the password prompt for docker-credential-helpers and pass.
# https://github.com/docker/docker-credential-helpers/issues/102
# Don't need to show actual password, mask it.
echo "Password verification:"
pass show docker-credential-helpers | sed -e 's/\(.\)/\*/g'