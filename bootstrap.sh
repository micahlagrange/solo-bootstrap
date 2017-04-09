#!/bin/bash
#
# Assumes ubuntu 16.04
#
# Before running:
# Set up .ssh/config for the remote server
# The user must be root or have sudo privileges with no password.
#
# Pass in the following arguments:
#
# 1. The ssh hostname of the server to configure
#
# 2. The json attributes for chef-solo
#
# 3. The cookbooks path on the local system
#
# Copyright 2017 Micah Turner
#

set -e

SSH_HOST=$1
JSON_ATTRS=$2
COOKBOOKS_PATH=$3

### THE BORING BIT
RUN_DIR=$(pwd)

if [ -z $JSON_ATTRS ] || [ -z $SSH_HOST ] || [ -z $COOKBOOKS_PATH ]; then
  echo -e "Must pass 3 args:\nSSH_HOST=$1\nJSON_ATTRS=$2\nCOOKBOOKS_PATH=$3\n"
  exit 1
fi

echo "Verifying ssh host $SSH_HOST"

if ssh "$SSH_HOST" true; then
  echo "...done"
else
  echo "Invalid host '$SSH_HOST'"
  exit 1
fi


echo "Verifying json attributes file $JSON_ATTRS"

if [ -f "$JSON_ATTRS" ]; then
  echo "...done"
else
  echo "Invalid json file: '$JSON_ATTRS'!"
  exit 1
fi

echo "Verifying cookbook path is a valid directory: $COOKBOOKS_PATH"

if [ -d "$COOKBOOKS_PATH" ]; then
  echo "...done"
else
  echo "Invalid cookbooks path: '$COOKBOOKS_PATH'"
  exit 1
fi

### Gather some data from the sytem to compile solo.rb
CHEF_HOME=$(ssh "$SSH_HOST" 'echo $HOME')
CHEF_PATH="$CHEF_HOME"/chef
echo -e "Chef home: $CHEF_HOME"
echo -e "Chef path: $CHEF_PATH"


### THE GOOD STUFF

echo "Creating directory structure and verifying dependencies"

# Install chef-solo dependencies
# Single quotes around 'EOF' to keep from expanding
ssh "$SSH_HOST" << 'EOF'
  sudo apt -qq update 
  DEBIAN_FRONTEND=noninteractive sudo apt -qq -y dist-upgrade
  DEBIAN_FRONTEND=noninteractive sudo apt -qq -y install ruby2.3 ruby2.3-dev wget build-essential rubygems
  sudo gem2.3 update --no-rdoc --no-ri >/dev/null
  sudo gem2.3 install ohai chef --no-rdoc --no-ri >/dev/null
EOF

# Cleanup from last run:
ssh "$SSH_HOST" "sudo rm -r $CHEF_PATH/nodes"

# Create chef directory
ssh "$SSH_HOST" "mkdir -p $CHEF_PATH/cookbooks"
cd "$COOKBOOKS_PATH"

# No single quotes around EOF so that $CHEF PATH gets expanded before cat
tempsolofile="$(mktemp --suffix solo.rb)"
cat << EOF > $tempsolofile
  file_cache_path "$CHEF_PATH"
  cookbook_path "$CHEF_PATH/cookbooks"
  json_attribs "$CHEF_PATH/node.json"
EOF

# Send cookbooks and solo.rb

tar czf - * | ssh "$SSH_HOST" 'tar xzf - -C '"$CHEF_PATH"'/cookbooks/'
scp $tempsolofile "$SSH_HOST":"$CHEF_PATH"/solo.rb
scp "$JSON_ATTRS" "$SSH_HOST":"$CHEF_PATH"/node.json
rm $tempsolofile

cd "$RUN_DIR"
ssh "$SSH_HOST" 'sudo chef-solo -c '"$CHEF_PATH"'/solo.rb -l debug > solo-output ; cat solo-output' > "$SSH_HOST"-solo-output

echo -e "\n\nRun complete. If the next line says '...DEBUG: Exiting', it was successful! Otherwise, look at $SSH_HOST-solo-output for logs\n"
tail -n1 "$SSH_HOST"-solo-output
